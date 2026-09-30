//
//  TidalStreamSupport.swift
//  Izzy
//
//  Tidal Hi-Res / Dolby Atmos playback support.
//
//  Tidal serves HI_RES_LOSSLESS (24-bit FLAC) and Dolby Atmos (E-AC-3 JOC) as
//  segmented DASH, which AVPlayer cannot play. The Python service rewrites the
//  DASH manifest into an HLS media playlist over the same fMP4 segments; this
//  file hands that playlist to AVPlayer through a custom URL scheme, so the
//  segments themselves still stream straight from Tidal's CDN.
//

import AVFoundation
import Foundation

// MARK: - Tidal Settings

enum TidalQualityPreference: String, CaseIterable, Identifiable {
    case max = "HI_RES_LOSSLESS"
    case lossless = "LOSSLESS"
    case high = "HIGH"
    case low = "LOW"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .max: return "Max (Hi-Res, up to 24-bit/192kHz)"
        case .lossless: return "Lossless (16-bit/44.1kHz FLAC)"
        case .high: return "High (320kbps AAC)"
        case .low: return "Low (96kbps AAC)"
        }
    }
}

enum TidalSettings {
    static let qualityKey = "tidalQuality"
    static let dolbyAtmosKey = "tidalDolbyAtmos"
    static let apiURLKey = "tidalApiUrl"
    static let apiKeyKey = "tidalApiKey"

    static var quality: TidalQualityPreference {
        TidalQualityPreference(rawValue: UserDefaults.standard.string(forKey: qualityKey) ?? "") ?? .max
    }

    static var dolbyAtmos: Bool {
        UserDefaults.standard.bool(forKey: dolbyAtmosKey)
    }

    static var apiURL: String? {
        let value = UserDefaults.standard.string(forKey: apiURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    static var apiKey: String? {
        let value = UserDefaults.standard.string(forKey: apiKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    /// Distinguishes cached stream URLs resolved under different settings, so
    /// toggling Atmos or quality takes effect on the next play.
    static var cacheSignature: String {
        "\(quality.rawValue)|\(dolbyAtmos)|\(apiURL ?? "")"
    }
}

// MARK: - HLS Playlist Loader

/// Serves an in-memory HLS media playlist to AVPlayer via a custom scheme.
/// Segment URIs inside the playlist are absolute https URLs, which AVPlayer
/// fetches directly - only the playlist goes through this delegate.
final class TidalHLSPlaylistLoader: NSObject, AVAssetResourceLoaderDelegate {
    static let scheme = "izzy-tidal-hls"

    private let playlistData: Data
    let queue = DispatchQueue(label: "izzy.tidal-hls-loader")

    init(playlist: String) {
        self.playlistData = Data(playlist.utf8)
    }

    /// Builds an asset for the playlist. Keep the returned loader alive for as
    /// long as the asset is playing - the resource loader holds it weakly.
    static func makeAsset(playlist: String, trackId: String) -> (AVURLAsset, TidalHLSPlaylistLoader)? {
        let safeId = trackId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "track"
        guard let url = URL(string: "\(scheme)://tidal/\(safeId).m3u8") else { return nil }
        let loader = TidalHLSPlaylistLoader(playlist: playlist)
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: loader.queue)
        return (asset, loader)
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard loadingRequest.request.url?.scheme == Self.scheme else { return false }

        if let info = loadingRequest.contentInformationRequest {
            info.contentType = "public.m3u-playlist"
            info.contentLength = Int64(playlistData.count)
            info.isByteRangeAccessSupported = false
        }
        if let dataRequest = loadingRequest.dataRequest {
            let start = Int(dataRequest.requestedOffset)
            if start < playlistData.count {
                let end = dataRequest.requestsAllDataToEndOfResource
                    ? playlistData.count
                    : min(playlistData.count, start + dataRequest.requestedLength)
                dataRequest.respond(with: playlistData.subdata(in: start..<end))
            }
        }
        loadingRequest.finishLoading()
        return true
    }
}

// MARK: - Direct-Stream Byte Proxy

/// Relays a remote audio file into AVPlayer through a resource loader so every
/// fetch carries a browser User-Agent. CDNs behind Cloudflare
/// (tracks.monochrome.st, the Deezer fallback) answer AVPlayer's default
/// UA-less requests with a 520 challenge page, which AVFoundation reports as
/// "Cannot Open / media format is not supported" (-11828). The bytes still
/// stream straight from the CDN - this loader only relays ranged requests.
final class TidalByteRangeLoader: NSObject, AVAssetResourceLoaderDelegate {
    static let scheme = "izzy-tidal-bytes"
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

    private let remoteURL: URL
    private var totalLength: Int64 = 0
    private var contentType = "public.audio"
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    init(remoteURL: URL) {
        self.remoteURL = remoteURL
    }

    /// Builds an asset whose bytes come through this loader. Keep the returned
    /// loader alive for as long as the asset is playing - the resource loader
    /// holds its delegate weakly.
    static func makeAsset(remoteURL: URL, trackId: String) -> (AVURLAsset, TidalByteRangeLoader)? {
        let safeId = trackId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "track"
        guard let url = URL(string: "\(scheme)://tidal/\(safeId).audio") else { return nil }
        let loader = TidalByteRangeLoader(remoteURL: remoteURL)
        let asset = AVURLAsset(url: url)
        asset.resourceLoader.setDelegate(loader, queue: loader.stateQueue)
        return (asset, loader)
    }

    private let stateQueue = DispatchQueue(label: "izzy.tidal-bytes-loader")

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard loadingRequest.request.url?.scheme == Self.scheme else { return false }
        // userInitiated: audio decode stalls otherwise; .utility throttles the
        // network fetches hard on battery power.
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.fulfill(loadingRequest)
        }
        return true
    }

    private func fulfill(_ loadingRequest: AVAssetResourceLoadingRequest) async {
        guard let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading()
            return
        }

        // AVPlayer probes content info alongside the first data request; it
        // needs the total size for seeking and progress.
        if let info = loadingRequest.contentInformationRequest {
            if totalLength <= 0 {
                await probeLength()
            }
            info.contentType = contentType
            info.isByteRangeAccessSupported = true
            info.contentLength = totalLength
        }

        let offset = dataRequest.requestedOffset
        let toEnd = dataRequest.requestsAllDataToEndOfResource
        let limit: Int64 = toEnd ? .max : Int64(dataRequest.requestedLength)

        // Bounded ranged fetches keep memory flat; AVPlayer's own requests are
        // usually small windows, so this only loops for open-ended requests.
        let chunkSize = Int64(2 * 1024 * 1024)
        var nextOffset = offset
        var responded: Int64 = 0

        while responded < limit {
            if loadingRequest.isCancelled {
                loadingRequest.finishLoading()
                return
            }
            let want = min(chunkSize, limit - responded)
            var request = URLRequest(url: remoteURL)
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("bytes=\(nextOffset)-\(nextOffset + want - 1)", forHTTPHeaderField: "Range")

            // The CDN occasionally answers a burst with a 5xx challenge; one
            // retry recovers without surfacing an error to the player.
            var data: Data?
            var ok = false
            for attempt in 0..<2 {
                do {
                    let (fetched, response) = try await session.data(for: request)
                    if let http = response as? HTTPURLResponse,
                       (200...299).contains(http.statusCode), !fetched.isEmpty {
                        data = fetched
                        ok = true
                        break
                    }
                } catch {
                    if attempt > 0 || loadingRequest.isCancelled {
                        if !loadingRequest.isCancelled {
                            loadingRequest.finishLoading(with: error)
                        }
                        return
                    }
                }
            }
            guard ok, let data, !data.isEmpty else {
                if responded == 0 {
                    loadingRequest.finishLoading(with: URLError(.badServerResponse))
                } else {
                    loadingRequest.finishLoading()
                }
                return
            }
            dataRequest.respond(with: data)
            responded += Int64(data.count)
            nextOffset += Int64(data.count)
            if Int64(data.count) < want { break } // EOF
        }
        loadingRequest.finishLoading()
    }

    /// One ranged request to learn the file size (Content-Range) and sniff the
    /// container from the leading bytes - AVFoundation only selects the FLAC
    /// parser when the UTI is precise; a generic "public.audio" never goes ready.
    private func probeLength() async {
        var request = URLRequest(url: remoteURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-63", forHTTPHeaderField: "Range")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return }
        if let contentRange = http.value(forHTTPHeaderField: "Content-Range"),
           let total = contentRange.split(separator: "/").last,
           let size = Int64(total) {
            totalLength = size
        } else if http.expectedContentLength > 0 {
            totalLength = http.expectedContentLength
        }
        if data.starts(with: Data("fLaC".utf8)) {
            contentType = "org.xiph.flac"
        } else if data.count > 7, data[4...7].elementsEqual(Data("ftyp".utf8)) {
            contentType = "public.mpeg-4-audio"
        } else if data.starts(with: Data("ID3".utf8)) {
            contentType = "public.mp3"
        }
    }
}
