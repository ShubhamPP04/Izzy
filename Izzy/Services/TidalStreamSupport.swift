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
