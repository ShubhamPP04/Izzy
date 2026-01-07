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
    let aiApiKey: String?
    let params: String?
    let country: String?
    
    init(action: String,
         query: String? = nil,
         videoId: String? = nil,
         browseId: String? = nil,
         playlistId: String? = nil,
         limit: Int? = nil,
         offset: Int? = nil,
         musicSource: String? = nil,
         aiApiKey: String? = nil,
         params: String? = nil,
         country: String? = nil) {
        self.action = action
        self.query = query
        self.videoId = videoId
        self.browseId = browseId
        self.playlistId = playlistId
        self.limit = limit
        self.offset = offset
        self.musicSource = musicSource
        self.aiApiKey = aiApiKey
        self.params = params
        self.country = country
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
    private var storedGeminiAPIKey: String? {
        let key = UserDefaults.standard.string(forKey: "geminiApiKey")?.trimmingCharacters(in: .whitespacesAndNewlines)
        return key?.isEmpty == true ? nil : key
    }
    
    var hasGeminiAPIKey: Bool {
        storedGeminiAPIKey != nil
    }
    
    private init() {}
    
    deinit {
        stopService()
    }
    
    // MARK: - Service Lifecycle
    
    func startService() throws {
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
                DispatchQueue.main.async {
                    self?.isServiceRunning = false
                    self?.stopInactivityTimer()
                    self?.cleanup()
                }
            }
            
            print("Python service started successfully with system Python: \(pythonPath)")
        } catch {
            cleanup()
            print("Failed to start Python service: \(error)")
            throw ServiceError.processCreationFailed
        }
    }
    
    func stopService() {
        guard isServiceRunning, let process = process else { return }
        
        stopInactivityTimer()
        process.terminate()
        process.waitUntilExit()
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
                print("❌ Attempt \(attempt) failed: \(error)")
                
                // On failure, mark service as not running to force restart
                if attempt < 3 {
                    print("🔄 Restarting service for retry...")
                    cleanup()
                    try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s before retry
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
            
            print("📤 Sending request: \(requestString.trimmingCharacters(in: .whitespacesAndNewlines))")
            
            inputPipe.fileHandleForWriting.write(requestString.data(using: .utf8)!)
            
            // Read response with timeout
            let responseData = try readResponseWithTimeout(from: outputPipe, timeout: timeout)
            
            print("📥 Received response data: \(responseData.count) bytes")
            
            if responseData.isEmpty {
                print("❌ Empty response from Python service")
                continuation.resume(throwing: ServiceError.invalidResponse)
                return
            }
            
            // Log the raw response for debugging (truncated for readability)
            if let responseString = String(data: responseData, encoding: .utf8) {
                let truncated = responseString.count > 500 ? String(responseString.prefix(500)) + "..." : responseString
                print("📄 Raw response: \(truncated)")
            }
            
            // Parse response
            let serviceResponse = try JSONDecoder().decode(ServiceResponse<T>.self, from: responseData)
            
            print("✅ Parsed response success: \(serviceResponse.success)")
            
            if serviceResponse.success, let data = serviceResponse.data {
                print("🎉 Returning successful data")
                continuation.resume(returning: data)
            } else {
                let error = ServiceError.pythonError(serviceResponse.error ?? "Unknown error")
                print("❌ Python service error: \(serviceResponse.error ?? "Unknown error")")
                continuation.resume(throwing: error)
            }
            
        } catch {
            print("💥 Service request failed with error: \(error)")
            continuation.resume(throwing: error)
        }
    }
    
    private func readResponseWithTimeout(from pipe: Pipe, timeout: TimeInterval) throws -> Data {
        let fileHandle = pipe.fileHandleForReading
        
        return try withTimeout(timeout) {
            var responseData = Data()
            var attempts = 0
            let maxAttempts = Int(timeout * 10) // Check every 100ms
            var braceCount = 0
            var inString = false
            var escapeNext = false
            var foundStart = false
            
            while attempts < maxAttempts {
                // Check if data is available
                let availableData = fileHandle.availableData
                if !availableData.isEmpty {
                    responseData.append(availableData)
                    
                    // Parse character by character to find complete JSON
                    if let string = String(data: responseData, encoding: .utf8) {
                        braceCount = 0
                        inString = false
                        escapeNext = false
                        foundStart = false
                        
                        for (index, char) in string.enumerated() {
                            if escapeNext {
                                escapeNext = false
                                continue
                            }
                            
                            if char == "\\" && inString {
                                escapeNext = true
                                continue
                            }
                            
                            if char == "\"" && !escapeNext {
                                inString.toggle()
                                continue
                            }
                            
                            if !inString {
                                if char == "{" {
                                    if !foundStart {
                                        foundStart = true
                                    }
                                    braceCount += 1
                                } else if char == "}" {
                                    braceCount -= 1
                                    
                                    // Complete JSON object found
                                    if foundStart && braceCount == 0 {
                                        let endIndex = string.index(string.startIndex, offsetBy: index + 1)
                                        let jsonString = String(string[..<endIndex])
                                        print("Found complete JSON response: \(jsonString.prefix(200))...")
                                        return jsonString.data(using: .utf8) ?? Data()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Wait a bit before trying again
                Thread.sleep(forTimeInterval: 0.1)
                attempts += 1
            }
            
            // If we get here, we didn't receive a complete response
            if responseData.isEmpty {
                throw ServiceError.timeout
            }
            
            // Try to return what we have if it looks like JSON
            if let string = String(data: responseData, encoding: .utf8),
               string.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
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

    func performAISearch(query: String, limit: Int = 20) async throws -> AISearchResponse {
        if !isServiceRunning {
            try ensureServiceRunning()
        }
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        let request = ServiceRequest(
            action: "ai_search",
            query: query,
            limit: limit,
            musicSource: currentSource,
            aiApiKey: storedGeminiAPIKey
        )
        return try await sendRequest(request, responseType: AISearchResponse.self)
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
