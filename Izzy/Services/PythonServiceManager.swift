//
//  PythonServiceManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation
import Combine

// MARK: - Service Errors

enum ServiceError: Error, LocalizedError {
    case scriptNotFound
    case processCreationFailed
    case processNotRunning
    case invalidResponse
    case pythonError(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "Python service script not found"
        case .processCreationFailed:
            return "Failed to create Python process"
        case .processNotRunning:
            return "Python service is not running"
        case .invalidResponse:
            return "Invalid response from Python service"
        case .pythonError(let message):
            return "Python service error: \(message)"
        case .timeout:
            return "Request timeout"
        }
    }
}

// MARK: - Service Request

struct ServiceRequest: Codable {
    let action: String
    let query: String?
    let videoId: String?
    let browseId: String?
    let playlistId: String?
    let limit: Int?
    let offset: Int?
    let musicSource: String?
    let params: String?
    let country: String?
    let trackTitle: String?
    let artistName: String?
    
    init(action: String,
         query: String? = nil,
         videoId: String? = nil,
         browseId: String? = nil,
         playlistId: String? = nil,
         limit: Int? = nil,
         offset: Int? = nil,
         musicSource: String? = nil,
         params: String? = nil,
         country: String? = nil,
         trackTitle: String? = nil,
         artistName: String? = nil) {
        self.action = action
        self.query = query
        self.videoId = videoId
        self.browseId = browseId
        self.playlistId = playlistId
        self.limit = limit
        self.offset = offset
        self.musicSource = musicSource
        self.params = params
        self.country = country
        self.trackTitle = trackTitle
        self.artistName = artistName
    }
}

// MARK: - Python Service Manager

class PythonServiceManager: ObservableObject {
    static let shared = PythonServiceManager()
    
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var isServiceRunning = false
    private let serviceQueue = DispatchQueue(label: "python-service", qos: .utility)
    private let timeout: TimeInterval = 45.0
    private var lastRequestTime = Date()  // 🔋 BATTERY EFFICIENCY: Track last request time
    private var inactivityTimer: DispatchSourceTimer?
    private let inactivityCheckInterval: TimeInterval = 60
    private let inactivityThreshold: TimeInterval = 240  // 4 minutes of inactivity before suspension
    // Serializes service lifecycle. `isServiceRunning` was read and mutated from
    // several threads at once (MusicSearchManager.init, AI search, MusicSearchTool
    // and the sendRequest retry loop), so every `guard !isServiceRunning` was a
    // check-then-act race: all callers saw `false` and each spawned an interpreter.
    // Recursive so ensureServiceRunning() can call startService() on one thread.
    private let lifecycleLock = NSRecursiveLock()
    
    private init() {}
    
    deinit {
        stopService()
    }
    
    // MARK: - Service Lifecycle
    
    func startService() throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        guard !isServiceRunning else { return }
        
        // Prefer bundled script inside the app resources
        let bundledScriptPath: String? = {
            if let resourceURL = Bundle.main.resourceURL {
                let scriptURL = resourceURL.appendingPathComponent("ytmusic_service.py")
                if FileManager.default.fileExists(atPath: scriptURL.path) {
                    return scriptURL.path
                }
            }
            return nil
        }()
        
        // Fallback to workspace script (useful for development builds)
        let workspacePath = "/Users/shubhamkumar/Downloads/Izzy/Izzy/ytmusic_service.py"
        let chosenScriptPath = bundledScriptPath ?? (FileManager.default.fileExists(atPath: workspacePath) ? workspacePath : nil)
        
        guard let scriptPath = chosenScriptPath else {
            print("Python script not found in bundle or workspace - service will use fallback mode")
            return
        }
        
        print("Found Python script at: \(scriptPath). Starting service...")
        do {
            try startServiceWithScript(at: scriptPath)
        } catch {
            print("Failed to start Python service: \(error) - continuing without service")
        }
    }
    
    private func startServiceWithScript(at path: String) throws {
        // Create pipes for communication
        inputPipe = Pipe()
        outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Create process
        process = Process()
        guard let process = process else {
            throw ServiceError.processCreationFailed
        }
        
        // Choose Python executable: prefer bundled venv/runtime inside app, then system Python
        let bundledPythonPath: String? = {
            // Check Resources/music_env first (created by build script)
            if let resURL = Bundle.main.resourceURL {
                let venvPython = resURL.appendingPathComponent("music_env/bin/python3").path
                if FileManager.default.fileExists(atPath: venvPython) { return venvPython }
                // Fallback to Resources/python_runtime provided by prior builds
                let runtimePython = resURL.appendingPathComponent("python_runtime/bin/python3").path
                if FileManager.default.fileExists(atPath: runtimePython) { return runtimePython }
            }
            return nil
        }()
        
        // Try multiple system Python paths as a final fallback
        let systemPythonCandidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python",
            "python3",
            "python"
        ]
        
        var selectedPythonPath = bundledPythonPath
        if selectedPythonPath == nil {
            for candidate in systemPythonCandidates {
                if FileManager.default.fileExists(atPath: candidate) || candidate == "python3" || candidate == "python" {
                    selectedPythonPath = candidate
                    break
                }
            }
        }
        
        guard let pythonPath = selectedPythonPath else { throw ServiceError.processCreationFailed }
        
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [path]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // 🔋 BATTERY EFFICIENCY: Set process priority to utility for better battery life
        process.qualityOfService = .utility
        
        // Set working directory
        if let resURL = Bundle.main.resourceURL {
            process.currentDirectoryURL = resURL
        } else {
            process.currentDirectoryURL = URL(fileURLWithPath: "/Users/shubhamkumar/Downloads/Izzy")
        }
        
        // 🔋 BATTERY OPTIMIZATION: Configure environment variables for reduced resource usage
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1" // Reduce buffering overhead
        environment["PYTHONDONTWRITEBYTECODE"] = "1" // Disable .pyc generation
        environment["PYTHONOPTIMIZE"] = "1" // Enable Python optimizations
        
        // If we are using a bundled venv, set VIRTUAL_ENV and PATH so python can find site-packages
        if let resURL = Bundle.main.resourceURL {
            let venvPath = resURL.appendingPathComponent("music_env").path
            if FileManager.default.fileExists(atPath: venvPath) {
                environment["VIRTUAL_ENV"] = venvPath
                let binPath = resURL.appendingPathComponent("music_env/bin").path
                let existingPath = environment["PATH"] ?? ""
                environment["PATH"] = binPath + ":" + existingPath
            }
        }
        // Suppress Python warnings to reduce log output
        environment["PYTHONWARNINGS"] = "ignore"
        process.environment = environment
        
        do {
            try process.run()
            
            // Read stderr in background to capture debug info
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let errorString = String(data: data, encoding: .utf8) {
                    print("Python stderr: \(errorString.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            
            // Wait for and consume startup confirmation
            do {
                guard let pipe = outputPipe else {
                    throw ServiceError.processCreationFailed
                }
                let startupData = try readResponseWithTimeout(from: pipe, timeout: 5.0)
                let startupString = String(data: startupData, encoding: .utf8) ?? "invalid"
                print("Python service ready: \(startupString)")
                
                // Verify it's the expected startup message
                if startupString.contains("service_ready") {
                    print("✅ Python service confirmed ready with ytmusicapi and yt-dlp")
                } else {
                    print("⚠️ Unexpected startup response: \(startupString)")
                }
            } catch {
                print("Failed to read startup confirmation: \(error)")
                // Don't fail here - service might still work
            }
            
            isServiceRunning = true
            lastRequestTime = Date()
            startInactivityTimer()
            
            // Monitor process termination
            process.terminationHandler = { [weak self] _ in
                guard let self else { return }
                self.stopInactivityTimer()
                self.cleanup() // takes the lock and clears isServiceRunning
            }
            
            print("Python service started successfully with system Python: \(pythonPath)")
        } catch {
            cleanup()
            print("Failed to start Python service: \(error)")
            throw ServiceError.processCreationFailed
        }
    }
    
    func stopService() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        // Do not gate on isServiceRunning. A failed request calls cleanup(), which
        // cleared that flag while the interpreter was still alive; gating here then
        // made stopService() a no-op and the process was never reaped.
        guard let process = process else {
            isServiceRunning = false
            return
        }

        stopInactivityTimer()
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        cleanup()
    }

    private func startInactivityTimer() {
        serviceQueue.async { [weak self] in
            guard let self = self else { return }
            if self.inactivityTimer != nil { return }
            let timer = DispatchSource.makeTimerSource(queue: self.serviceQueue)
            timer.schedule(deadline: .now() + self.inactivityCheckInterval, repeating: self.inactivityCheckInterval)
            timer.setEventHandler { [weak self] in
                self?.suspendServiceIfNeeded()
            }
            self.inactivityTimer = timer
            timer.activate()
        }
    }

    private func stopInactivityTimer() {
        inactivityTimer?.cancel()
        inactivityTimer = nil
    }
    
    private func cleanup() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        // Never drop the handle to a live interpreter. sendRequest() calls cleanup()
        // between retries; without this terminate, the ~50MB Python process was
        // orphaned and a fresh one spawned beside it on every failed request.
        if let process = process, process.isRunning {
            process.terminate()
        }

        inputPipe = nil
        outputPipe = nil
        process = nil
        isServiceRunning = false
    }
    
    // MARK: - Request Handling
    
    func sendRequest<T: Codable>(_ request: ServiceRequest, responseType: T.Type) async throws -> T {
        // Retry logic: try up to 3 times, restarting service on failure
        var lastError: Error = ServiceError.processNotRunning
        
        for attempt in 1...3 {
            // Ensure service is running
            if !isServiceRunning {
                print("🔄 Attempt \(attempt): Python service not running, restarting...")
                try await restartService()
            }
            
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    serviceQueue.async { [weak self] in
                        guard let self = self else {
                            continuation.resume(throwing: ServiceError.processNotRunning)
                            return
                        }
                        self.performRequest(request, responseType: responseType, continuation: continuation)
                    }
                }
            } catch {
                lastError = error
                
                if attempt < 3 {
                    // Only recycle the interpreter if it actually died. A single
                    // failed request (bad upstream response, decode error) says
                    // nothing about interpreter health, and tearing the service down
                    // here killed it out from under other in-flight requests.
                    if process?.isRunning != true {
                        cleanup()
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        
        throw lastError
    }
    
    private func performRequest<T: Codable>(
        _ request: ServiceRequest,
        responseType: T.Type,
        continuation: CheckedContinuation<T, Error>
    ) {
        guard let inputPipe = inputPipe,
              let outputPipe = outputPipe else {
            continuation.resume(throwing: ServiceError.processNotRunning)
            return
        }
        
        do {
            // Encode and send request
            let requestData = try JSONEncoder().encode(request)
            let requestString = String(data: requestData, encoding: .utf8)! + "\n"
            
            inputPipe.fileHandleForWriting.write(requestString.data(using: .utf8)!)
            
            // Read response with timeout
            let responseData = try readResponseWithTimeout(from: outputPipe, timeout: timeout)
            
            if responseData.isEmpty {
                continuation.resume(throwing: ServiceError.invalidResponse)
                return
            }
            
            // Parse response
            let serviceResponse = try JSONDecoder().decode(ServiceResponse<T>.self, from: responseData)
            
            if serviceResponse.success, let data = serviceResponse.data {
                continuation.resume(returning: data)
            } else {
                let error = ServiceError.pythonError(serviceResponse.error ?? "Unknown error")
                continuation.resume(throwing: error)
            }
            
        } catch {
            continuation.resume(throwing: error)
        }
    }
    
    private func readResponseWithTimeout(from pipe: Pipe, timeout: TimeInterval) throws -> Data {
        let fileHandle = pipe.fileHandleForReading

        return try withTimeout(timeout) {
            // Incremental JSON scanner: each byte is examined exactly once, so a
            // response costs O(total bytes) instead of re-decoding and re-scanning
            // the whole accumulated buffer on every chunk (previously O(n^2)).
            // `availableData` blocks in the kernel until bytes arrive, so there is
            // no polling wakeup; the enclosing `withTimeout` supplies the deadline.
            var responseData = Data()
            var braceDepth = 0
            var inString = false
            var escapeNext = false
            var sawObjectStart = false

            while true {
                let chunk = fileHandle.availableData
                if chunk.isEmpty { break } // EOF: pipe closed

                var scanned = responseData.count
                responseData.append(chunk)

                for byte in chunk {
                    scanned += 1

                    if escapeNext {
                        escapeNext = false
                        continue
                    }

                    switch byte {
                    case 0x5C where inString: // backslash
                        escapeNext = true
                    case 0x22: // double quote
                        inString.toggle()
                    case 0x7B where !inString: // {
                        sawObjectStart = true
                        braceDepth += 1
                    case 0x7D where !inString: // }
                        braceDepth -= 1
                        if sawObjectStart && braceDepth == 0 {
                            // Complete top-level object; ignore any trailing bytes.
                            return Data(responseData.prefix(scanned))
                        }
                    default:
                        break
                    }
                }
            }

            if responseData.isEmpty {
                throw ServiceError.timeout
            }

            // Partial read at EOF: hand back anything that still looks like JSON.
            if sawObjectStart {
                return responseData
            }

            throw ServiceError.invalidResponse
        }
    }
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () throws -> T) throws -> T {
        var result: Result<T, Error>?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            do {
                let value = try operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            throw ServiceError.timeout
        }
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw ServiceError.invalidResponse
        }
    }
    
    private func restartService() async throws {
        // Idempotent: concurrent callers all observe !isServiceRunning and pile in
        // here. Without this check the second caller tears down the interpreter the
        // first has just started, which produces a restart storm.
        lifecycleLock.lock()
        let alreadyHealthy = isServiceRunning && process?.isRunning == true
        lifecycleLock.unlock()
        if alreadyHealthy { return }

        stopService()
        
        // Wait a bit before restarting
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        do {
            try startService()
        } catch {
            print("Service restart failed: \(error)")
            // Don't throw to prevent crash
        }
    }
    
    // 🔋 BATTERY EFFICIENCY: Add method to suspend service when not needed
    func suspendServiceIfNeeded() {
        // Only suspend if no requests have been made recently
        let timeSinceLastRequest = Date().timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest > inactivityThreshold {
            print("🔋 Suspending Python service due to inactivity")
            stopService()
        }
    }
    
    // 🔋 BATTERY EFFICIENCY: Add method to resume service when needed
    func ensureServiceRunning() throws {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        if !isServiceRunning {
            print("🔋 Resuming Python service")
            try startService()
        }
        lastRequestTime = Date()
        startInactivityTimer()
    }
}

// MARK: - Convenience Methods

extension PythonServiceManager {
    
    func searchMusic(query: String, limit: Int = 20) async throws -> MusicSearchResults {
        // Ensure service is running - restart if needed
        if !isServiceRunning {
            print("🔄 Python service not running, restarting...")
            try ensureServiceRunning()
        }
        
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        print("🎵 Current music source from UserDefaults: '\(currentSource)'")
        
        let request = ServiceRequest(action: "search", query: query, limit: limit, musicSource: currentSource)
        return try await sendRequest(request, responseType: MusicSearchResults.self)
    }

    func getStreamInfo(videoId: String, musicSource: String? = nil) async throws -> StreamInfo {
        // Use provided music source, or fall back to current setting
        let sourceToUse = musicSource ?? UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "stream", videoId: videoId, musicSource: sourceToUse)
        return try await sendRequest(request, responseType: StreamInfo.self)
    }
    
    func getDownloadStreamInfo(videoId: String, musicSource: String? = nil) async throws -> StreamInfo {
        // Use provided music source, or fall back to current setting
        let sourceToUse = musicSource ?? UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        // Use download_stream action for Hi-Res quality preference
        let request = ServiceRequest(action: "download_stream", videoId: videoId, musicSource: sourceToUse)
        return try await sendRequest(request, responseType: StreamInfo.self)
    }
    
    func getAlbumTracks(browseId: String) async throws -> [SearchResult] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "album_tracks", browseId: browseId, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    func getPlaylistTracks(playlistId: String) async throws -> [SearchResult] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "playlist_tracks", playlistId: playlistId, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    func getArtistSongs(browseId: String) async throws -> [SearchResult] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "artist_songs", browseId: browseId, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    /// Get artist songs with pagination (for Tidal Load More)
    func getArtistSongsWithOffset(browseId: String, offset: Int, limit: Int = 20) async throws -> [SearchResult] {
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "artist_songs_paginated", browseId: browseId, limit: limit, offset: offset, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    /// Get playlist tracks with pagination (All sources)
    func getPlaylistTracksWithOffset(playlistId: String, offset: Int, limit: Int = 20) async throws -> [SearchResult] {
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "playlist_tracks_paginated", playlistId: playlistId, limit: limit, offset: offset, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    func getWatchPlaylist(videoId: String, playlistId: String? = nil) async throws -> [SearchResult] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "watch_playlist", videoId: videoId, playlistId: playlistId, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    func getSongSuggestions(videoId: String) async throws -> [SearchResult] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "song_suggestions", videoId: videoId, musicSource: currentSource)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
    
    /// Fetch lyrics for a song by video/track ID, passing title/artist for LRCLIB
    func getLyrics(videoId: String, title: String? = nil, artist: String? = nil) async throws -> LyricsData {
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(
            action: "lyrics",
            videoId: videoId,
            musicSource: currentSource,
            trackTitle: title,
            artistName: artist
        )
        return try await sendRequest(request, responseType: LyricsData.self)
    }
    
    /// Load more Tidal songs with pagination (Tidal only)
    func loadMoreTidalSongs(query: String, offset: Int, limit: Int = 20) async throws -> LoadMoreSongsResponse {
        let request = ServiceRequest(
            action: "load_more_songs",
            query: query,
            limit: limit,
            offset: offset,
            musicSource: "tidal"
        )
        return try await sendRequest(request, responseType: LoadMoreSongsResponse.self)
    }
    
    // MARK: - Home & Discovery Methods
    
    func getHomeFeed() async throws -> [HomeSection] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "home", musicSource: currentSource)
        return try await sendRequest(request, responseType: [HomeSection].self)
    }
    
    func getCharts(country: String = "ZZ") async throws -> ChartsData {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "charts", musicSource: currentSource, country: country)
        return try await sendRequest(request, responseType: ChartsData.self)
    }
    
    func getMoodCategories() async throws -> [String: [MoodCategory]] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "mood_categories", musicSource: currentSource)
        return try await sendRequest(request, responseType: [String: [MoodCategory]].self)
    }
    
    func getMoodPlaylists(params: String) async throws -> [SearchResult] {
        // Get the current music source from UserDefaults
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let request = ServiceRequest(action: "mood_playlists", musicSource: currentSource, params: params)
        return try await sendRequest(request, responseType: [SearchResult].self)
    }
}

// MARK: - Service Health Check

extension PythonServiceManager {
    
    var isHealthy: Bool {
        return isServiceRunning && process?.isRunning == true
    }
    
    func healthCheck() async -> Bool {
        guard isHealthy else { return false }
        
        do {
            // Try a simple search to verify service is responding
            _ = try await searchMusic(query: "test", limit: 1)
            return true
        } catch {
            print("Service health check failed: \(error)")
            return false
        }
    }
}
