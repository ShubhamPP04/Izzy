//
//  DownloadManager.swift
//  Izzy
//
//  Download manager for saving songs locally
//  Supports Tidal (Hi-Res/Lossless), YouTube Music, and JioSaavn
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Download Task

struct DownloadTask: Identifiable {
    let id: String
    let trackId: String
    let title: String
    let artist: String
    let quality: String?
    let musicSource: String?
    var status: DownloadStatus
    var progress: Double
    var error: String?
    var filePath: URL?
    let startedAt: Date
    
    enum DownloadStatus: String {
        case pending
        case downloading
        case processing
        case completed
        case failed
        case cancelled
    }
}

// MARK: - Download Manager

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var activeTasks: [DownloadTask] = []
    @Published var isDownloading = false
    
    private let pythonService = PythonServiceManager.shared
    private var downloadDirectory: URL {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let izzyDir = downloadsDir.appendingPathComponent("Izzy Music")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: izzyDir.path) {
            try? FileManager.default.createDirectory(at: izzyDir, withIntermediateDirectories: true)
        }
        
        return izzyDir
    }
    
    private var tempDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("IzzyDownloads")
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        return tempDir
    }
    
    private init() {}
    
    // MARK: - Download Methods
    
    /// Download a song with quality preference (HI_RES first for Tidal)
    func downloadSong(_ song: SearchResult) async {
        let taskId = UUID().uuidString
        let task = DownloadTask(
            id: taskId,
            trackId: song.videoId ?? song.id,
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
            quality: song.audioQuality,
            musicSource: song.musicSource,
            status: .pending,
            progress: 0,
            startedAt: Date()
        )
        
        activeTasks.append(task)
        isDownloading = true
        
        print("🎵 Starting download: \(song.artist ?? "Unknown") - \(song.title)")
        
        do {
            // Update status to downloading
            updateTaskStatus(taskId, status: .downloading, progress: 0.1)
            
            // Get stream info from Python service (uses Hi-Res quality for Tidal downloads)
            guard let videoId = song.videoId else {
                print("❌ No video ID for song: \(song.title)")
                throw DownloadError.invalidTrackId
            }
            
            print("📡 Getting stream info for: \(videoId) (source: \(song.musicSource ?? "unknown"))")
            let streamInfo = try await pythonService.getDownloadStreamInfo(videoId: videoId, musicSource: song.musicSource)
            
            print("📡 Stream URL: \(streamInfo.url.prefix(100))...")
            print("📡 Quality: \(streamInfo.quality ?? "unknown")")
            
            updateTaskStatus(taskId, status: .downloading, progress: 0.2)
            
            // Get the stream URL
            guard let streamURL = URL(string: streamInfo.url) else {
                print("❌ Invalid stream URL")
                throw DownloadError.invalidStreamURL
            }
            
            // Determine file extension based on quality and source
            let fileExtension = getFileExtension(for: streamInfo, musicSource: song.musicSource)
            let sanitizedTitle = sanitizeFilename(song.title)
            let sanitizedArtist = sanitizeFilename(song.artist ?? "Unknown")
            let filename = "\(sanitizedArtist) - \(sanitizedTitle).\(fileExtension)"
            
            print("📁 Download destination: \(filename)")
            
            // Use temp file first, then process with metadata
            let tempAudioFile = tempDirectory.appendingPathComponent("audio_\(taskId).\(fileExtension)")
            let destinationURL = downloadDirectory.appendingPathComponent(filename)
            
            // Download the audio file
            updateTaskStatus(taskId, status: .downloading, progress: 0.3)
            
            print("📥 Downloading audio file...")
            try await downloadFile(from: streamURL, to: tempAudioFile, taskId: taskId)
            
            // Verify file was downloaded
            let fileSize = try FileManager.default.attributesOfItem(atPath: tempAudioFile.path)[.size] as? Int64 ?? 0
            print("📥 Temp file size: \(fileSize / 1024) KB")
            
            if fileSize < 1000 {
                print("❌ Downloaded file too small, likely an error")
                throw DownloadError.httpError
            }
            
            // Update to processing status
            updateTaskStatus(taskId, status: .processing, progress: 0.9)
            
            // Download album art and embed metadata
            print("🎨 Embedding metadata and album art...")
            await embedMetadata(
                audioFile: tempAudioFile,
                destination: destinationURL,
                title: song.title,
                artist: song.artist ?? "Unknown",
                thumbnailURL: song.thumbnailURL,
                fileExtension: fileExtension
            )
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempAudioFile)
            
            // Mark as completed
            updateTaskStatus(taskId, status: .completed, progress: 1.0, filePath: destinationURL)
            
            print("✅ Downloaded: \(filename)")
            
            // Show notification
            showDownloadNotification(title: song.title, artist: song.artist ?? "Unknown", success: true)
            
        } catch {
            print("❌ Download failed: \(error)")
            updateTaskStatus(taskId, status: .failed, error: error.localizedDescription)
            showDownloadNotification(title: song.title, artist: song.artist ?? "Unknown", success: false, error: error.localizedDescription)
        }
        
        // Remove from active tasks after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.activeTasks.removeAll { $0.id == taskId }
            if self?.activeTasks.isEmpty == true {
                self?.isDownloading = false
            }
        }
    }
    
    /// Download from FavoriteSong
    func downloadSong(_ song: FavoriteSong) async {
        let searchResult = SearchResult(
            id: song.id,
            type: .song,
            title: song.title,
            artist: song.artist,
            thumbnailURL: song.thumbnailURL,
            duration: song.duration,
            explicit: false,
            videoId: song.videoId,
            browseId: nil,
            year: nil,
            playCount: nil,
            musicSource: song.musicSource,
            audioQuality: song.audioQuality
        )
        await downloadSong(searchResult)
    }
    
    /// Download from Track
    func downloadSong(_ track: Track) async {
        let searchResult = SearchResult(
            id: track.id,
            type: .song,
            title: track.title,
            artist: track.artist,
            thumbnailURL: track.thumbnailURL,
            duration: track.duration,
            explicit: track.explicit,
            videoId: track.videoId,
            browseId: nil,
            year: track.year,
            playCount: nil,
            musicSource: track.musicSource,
            audioQuality: track.audioQuality
        )
        await downloadSong(searchResult)
    }
    
    // MARK: - Private Methods
    
    private func downloadFile(from url: URL, to destination: URL, taskId: String) async throws {
        // Use URLSession download task for more reliable full file downloads
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 600 // 10 minutes
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        
        // Create a delegate to handle redirects
        let delegate = DownloadDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        print("📥 Attempting download from: \(url.absoluteString.prefix(150))...")
        
        // Create request with headers that mimic a browser
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("https://listen.tidal.com", forHTTPHeaderField: "Origin")
        request.setValue("https://listen.tidal.com/", forHTTPHeaderField: "Referer")
        
        // Use data task with manual handling for better control
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.httpError
        }
        
        print("📥 Response status: \(httpResponse.statusCode)")
        print("📥 Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        print("📥 Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
        print("📥 Data received: \(data.count / 1024) KB")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            throw DownloadError.httpError
        }
        
        guard data.count > 10000 else { // At least 10KB for a valid audio file
            print("❌ Data too small: \(data.count) bytes")
            // Print response body for debugging if it looks like text
            if data.count < 5000, let responseText = String(data: data, encoding: .utf8) {
                print("📥 Response body: \(responseText.prefix(500))")
            }
            throw DownloadError.httpError
        }
        
        // Write data to file
        try data.write(to: destination)
        print("✅ Saved \(data.count / 1024) KB to temp file")
        
        await MainActor.run {
            updateTaskStatus(taskId, status: .downloading, progress: 0.85)
        }
    }
    
    private func updateTaskStatus(_ taskId: String, status: DownloadTask.DownloadStatus, progress: Double? = nil, error: String? = nil, filePath: URL? = nil) {
        if let index = activeTasks.firstIndex(where: { $0.id == taskId }) {
            activeTasks[index].status = status
            if let progress = progress {
                activeTasks[index].progress = progress
            }
            if let error = error {
                activeTasks[index].error = error
            }
            if let filePath = filePath {
                activeTasks[index].filePath = filePath
            }
        }
    }
    
    private func getFileExtension(for streamInfo: StreamInfo, musicSource: String?) -> String {
        // Check if it's FLAC (Tidal lossless)
        if streamInfo.mimeType?.contains("flac") == true {
            return "flac"
        }
        
        // Check content type
        if let mimeType = streamInfo.mimeType {
            if mimeType.contains("audio/mp4") || mimeType.contains("audio/m4a") {
                return "m4a"
            } else if mimeType.contains("audio/mpeg") {
                return "mp3"
            } else if mimeType.contains("audio/flac") {
                return "flac"
            } else if mimeType.contains("audio/ogg") {
                return "ogg"
            } else if mimeType.contains("audio/webm") {
                return "webm"
            }
        }
        
        // Default based on source
        if musicSource == "tidal" {
            return "flac" // Tidal typically serves FLAC for lossless
        }
        
        return "m4a" // Default for YouTube Music and JioSaavn
    }
    
    private func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Metadata Embedding
    
    private func embedMetadata(audioFile: URL, destination: URL, title: String, artist: String, thumbnailURL: String?, fileExtension: String) async {
        // Download album art first
        var albumArtPath: URL? = nil
        
        if let thumbURL = thumbnailURL, let url = URL(string: thumbURL) {
            let artPath = tempDirectory.appendingPathComponent("cover_\(UUID().uuidString).jpg")
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: artPath)
                albumArtPath = artPath
                print("📷 Downloaded album art")
            } catch {
                print("⚠️ Failed to download album art: \(error)")
            }
        }
        
        // Try to use ffmpeg to embed metadata
        let ffmpegSuccess = await embedWithFFmpeg(
            audioFile: audioFile,
            destination: destination,
            title: title,
            artist: artist,
            albumArtPath: albumArtPath,
            fileExtension: fileExtension
        )
        
        if !ffmpegSuccess {
            // Fallback: just copy the file without metadata
            print("⚠️ FFmpeg not available, copying without embedded metadata")
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: audioFile, to: destination)
            } catch {
                print("❌ Failed to copy file: \(error)")
            }
        }
        
        // Clean up album art
        if let artPath = albumArtPath {
            try? FileManager.default.removeItem(at: artPath)
        }
    }
    
    private func embedWithFFmpeg(audioFile: URL, destination: URL, title: String, artist: String, albumArtPath: URL?, fileExtension: String) async -> Bool {
        // Check if ffmpeg is available
        let ffmpegPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        
        var ffmpegPath: String? = nil
        for path in ffmpegPaths {
            if FileManager.default.fileExists(atPath: path) {
                ffmpegPath = path
                break
            }
        }
        
        guard let ffmpeg = ffmpegPath else {
            print("⚠️ FFmpeg not found")
            return false
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: ffmpeg)
                
                var arguments: [String] = ["-i", audioFile.path]
                
                // Add album art if available
                if let artPath = albumArtPath {
                    if fileExtension == "flac" {
                        // For FLAC, use -metadata_block_picture
                        arguments += ["-i", artPath.path]
                        arguments += ["-map", "0:a", "-map", "1:0"]
                        arguments += ["-c:a", "copy"]
                        arguments += ["-metadata:s:v", "title=Album cover"]
                        arguments += ["-metadata:s:v", "comment=Cover (front)"]
                        arguments += ["-disposition:v", "attached_pic"]
                    } else {
                        // For M4A/MP4, embed as cover art
                        arguments += ["-i", artPath.path]
                        arguments += ["-map", "0:a", "-map", "1:0"]
                        arguments += ["-c:a", "copy"]
                        arguments += ["-c:v", "mjpeg"]
                        arguments += ["-disposition:v", "attached_pic"]
                    }
                } else {
                    arguments += ["-c:a", "copy"]
                }
                
                // Add metadata
                arguments += ["-metadata", "title=\(title)"]
                arguments += ["-metadata", "artist=\(artist)"]
                arguments += ["-metadata", "album=\(title)"] // Use title as album name
                arguments += ["-metadata", "comment=Downloaded with Izzy"]
                
                // Output file
                arguments += ["-y", destination.path]
                
                process.arguments = arguments
                
                // Suppress output
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        print("✅ Embedded metadata with FFmpeg")
                        continuation.resume(returning: true)
                    } else {
                        print("❌ FFmpeg failed with status: \(process.terminationStatus)")
                        continuation.resume(returning: false)
                    }
                } catch {
                    print("❌ Failed to run FFmpeg: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func showDownloadNotification(title: String, artist: String, success: Bool, error: String? = nil) {
        // Show macOS notification
        let content = UNMutableNotificationContent()
        
        if success {
            content.title = "Download Complete"
            content.body = "\(artist) - \(title)"
            content.sound = .default
            print("🎵 Download complete: \(artist) - \(title)")
        } else {
            content.title = "Download Failed"
            content.body = "\(artist) - \(title)\n\(error ?? "Unknown error")"
            content.sound = .default
            print("❌ Download failed: \(artist) - \(title) - \(error ?? "Unknown error")")
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Request notification permissions
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            }
        }
    }
    
    /// Open downloads folder in Finder
    func openDownloadsFolder() {
        NSWorkspace.shared.open(downloadDirectory)
    }
    
    /// Cancel a download task
    func cancelTask(_ taskId: String) {
        updateTaskStatus(taskId, status: .cancelled)
        activeTasks.removeAll { $0.id == taskId }
        if activeTasks.isEmpty {
            isDownloading = false
        }
    }
}

// MARK: - Download Errors

enum DownloadError: LocalizedError {
    case invalidTrackId
    case invalidStreamURL
    case httpError
    case fileWriteError
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidTrackId:
            return "Invalid track ID"
        case .invalidStreamURL:
            return "Could not get stream URL"
        case .httpError:
            return "HTTP request failed"
        case .fileWriteError:
            return "Failed to write file"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

// MARK: - Download Delegate for Redirect Handling

class DownloadDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("📥 Following redirect to: \(request.url?.absoluteString.prefix(100) ?? "unknown")...")
        // Follow all redirects
        completionHandler(request)
    }
}
