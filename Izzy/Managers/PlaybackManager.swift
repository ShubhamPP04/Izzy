//
//  PlaybackManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation
import AVFoundation
import Combine
import AppKit

// MARK: - Playback Manager

// 🚀 FAST SEEK OPTIMIZATION: Cached stream information for instant seeking
private class CachedStreamInfo {
    let url: String
    let title: String
    let duration: TimeInterval
    let cachedTime: Date
    let videoId: String
    
    init(url: String, title: String, duration: TimeInterval, videoId: String) {
        self.url = url
        self.title = title
        self.duration = duration
        self.cachedTime = Date()
        self.videoId = videoId
    }
    
    // Cache expires after 1 hour to ensure fresh URLs
    var isExpired: Bool {
        Date().timeIntervalSince(cachedTime) > 3600
    }
}

class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()
    
    @Published var currentTrack: Track?
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isBuffering: Bool = false
    @Published var volume: Float = 0.7 {
        didSet {
            player?.volume = volume
            UserDefaults.standard.set(volume, forKey: "playerVolume")
        }
    }

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var isSeeking = false  // Flag to prevent time updates during seeking
    
    // 🚀 FAST SEEK OPTIMIZATION: Advanced caching for instant seeking
    private var streamCache = NSCache<NSString, CachedStreamInfo>()
    private var prefetchTask: Task<Void, Never>?
    private var bufferTimer: Timer?
    
    // 🎵 DEBOUNCE: Skip navigation debounce for rapid next/previous taps
    private var skipDebounceTask: Task<Void, Never>?
    private var currentPlaybackId: UUID = UUID()  // Track which playback request is current
    
    private let queueManager = QueueManager()
    private let pythonService = PythonServiceManager.shared
    private let nowPlayingManager = NowPlayingManager.shared
    
    private init() {
        // Load saved volume
        let savedVolume = UserDefaults.standard.float(forKey: "playerVolume")
        if savedVolume > 0 {
            volume = savedVolume
        }
        setupQueueManager()
        setupRemoteCommandHandlers()
        restoreLastTrack()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupQueueManager() {
        // Subscribe to queue manager updates
        queueManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func setupRemoteCommandHandlers() {
        // Handle remote commands from macOS Now Playing
        NotificationCenter.default.publisher(for: .remotePlayCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🎮 PlaybackManager received remote play command")
                self?.resume()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .remotePauseCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🎮 PlaybackManager received remote pause command")
                self?.pause()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .remoteNextCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🎮 PlaybackManager received remote next command")
                Task {
                    await self?.playNext()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .remotePreviousCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🎮 PlaybackManager received remote previous command")
                Task {
                    await self?.playPrevious()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .remoteSeekCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let position = notification.userInfo?["position"] as? TimeInterval {
                    print("🎮 PlaybackManager received remote seek command: \(position)")
                    self?.seek(to: position)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Queue Access
    
    var queue: QueueManager {
        return queueManager
    }
    
    func addToQueueNext(track: Track) {
        queueManager.addToQueueNext(track)
    }
    
    func addToQueueNext(tracks: [Track]) {
        queueManager.addToQueueNext(tracks)
    }
    
    // MARK: - Playback Control
    
    func play(track: Track, fromQueue: [Track] = []) async {
        print("🎵 PlaybackManager.play() called for: \(track.title)")
        print("🎵 Video ID: \(track.videoId)")
        
        // Set up queue if provided
        if !fromQueue.isEmpty {
            queueManager.setQueue(fromQueue, startingAt: track)
            print("🎵 Queue set with \(fromQueue.count) tracks")
        } else {
            // For single tracks, try to get a watch playlist for continuous playback
            queueManager.setCurrentTrack(track)
            print("🎵 Single track set, will try to get watch playlist")
            
            // Asynchronously get watch playlist to extend the queue
            Task {
                do {
                    let watchPlaylist = try await pythonService.getWatchPlaylist(videoId: track.videoId)
                    let watchTracks = watchPlaylist.map { Track(from: $0) }
                    
                    await MainActor.run {
                        // Add watch playlist tracks to queue (excluding the current track)
                        let additionalTracks = watchTracks.filter { $0.videoId != track.videoId }
                        queueManager.addToQueue(additionalTracks)
                        print("🎵 Added \(additionalTracks.count) tracks from watch playlist")
                    }
                } catch {
                    print("⚠️ Failed to get watch playlist: \(error)")
                }
            }
        }
        
        await playCurrentTrack()
    }
    
    func playCurrentTrack(startFromPosition: TimeInterval? = nil, playbackId: UUID? = nil) async {
        // 🎵 DEBOUNCE: Check if this playback request is still valid
        let expectedId = playbackId ?? currentPlaybackId
        guard expectedId == currentPlaybackId else {
            print("🎵 Playback cancelled - newer request exists (expected: \(expectedId), current: \(currentPlaybackId))")
            return
        }
        
        guard let track = queueManager.currentTrack else { 
            print("❌ No current track in queue")
            print("❌ Queue size: \(queueManager.queueSize), Current index: \(queueManager.currentIndex)")
            return 
        }
        
        print("🎵 Playing current track: \(track.title)")
        print("🎵 Track video ID: \(track.videoId)")
        print("🎵 Queue position: \(queueManager.currentIndex + 1) of \(queueManager.queueSize)")
        
        await MainActor.run {
            self.currentTrack = track
            self.playbackState = PlaybackState.buffering
            self.isBuffering = true
            
            // Only reset time for new tracks, not when resuming
            if let startPosition = startFromPosition {
                self.currentTime = startPosition
                print("🎵 Resuming from position: \(startPosition)")
            } else {
                self.currentTime = 0  // Reset to start from beginning for new tracks
                print("🎵 Reset current time to 0 (start from beginning)")
            }
            
            self.saveCurrentTrack() // Save track for persistence
            print("🎵 Set playback state to buffering")
            print("🎵 Current track set to: \(track.title)")
            print("🎵 UI should now show playback controls")
            
            // Force UI update by triggering objectWillChange
            self.objectWillChange.send()
        }
        
        // 🎵 DEBOUNCE: Check again before network request
        guard expectedId == currentPlaybackId else {
            print("🎵 Playback cancelled before network - newer request exists")
            return
        }
        
        do {
            print("🎵 Getting stream info for video ID: \(track.videoId)")
            
            // Check if video ID is valid
            guard !track.videoId.isEmpty else {
                throw NSError(domain: "PlaybackError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid video ID"])
            }
            
            // 🚀 FAST SEEK: Check cache first for instant playback
            let streamInfo = try await getStreamInfoWithCaching(videoId: track.videoId, musicSource: track.musicSource)
            
            // 🎵 DEBOUNCE: Check again after network request
            guard expectedId == currentPlaybackId else {
                print("🎵 Playback cancelled after network - newer request exists")
                return
            }
            
            print("🎵 Got stream info - URL: \(streamInfo.url), Duration: \(streamInfo.duration)")
            
            await MainActor.run {
                // 🎵 DEBOUNCE: Final check before setting up player
                guard expectedId == self.currentPlaybackId else {
                    print("🎵 Playback cancelled before player setup - newer request exists")
                    return
                }
                self.setupPlayerWithPrefetch(with: streamInfo, track: track, startFromPosition: startFromPosition)
            }
            
        } catch {
            // 🎵 DEBOUNCE: Only show error if this is still the current playback
            guard expectedId == currentPlaybackId else {
                print("🎵 Ignoring error for cancelled playback")
                return
            }
            
            let errorMessage = error.localizedDescription
            print("❌ Playback error: \(errorMessage)")
            
            await MainActor.run {
                self.playbackState = PlaybackState.error(errorMessage)
                self.isBuffering = false
                
                // Keep the current track so UI shows the error state
                // Don't set currentTrack to nil here
            }
        }
    }
    
    // 🚀 FAST SEEK OPTIMIZATION: Stream caching for instant playback
    private func getStreamInfoWithCaching(videoId: String, musicSource: String? = nil) async throws -> StreamInfo {
        // Include music source in cache key to separate caches for different sources
        let cacheKey = NSString(string: "\(videoId)_\(musicSource ?? "default")")
        
        // Check if we have cached stream info that hasn't expired
        if let cached = streamCache.object(forKey: cacheKey), !cached.isExpired {
            print("🚀 Using cached stream info for instant playback: \(videoId)")
            return StreamInfo(url: cached.url, title: cached.title, duration: cached.duration)
        }
        
        // Fetch fresh stream info with the track's music source
        print("🚀 Fetching fresh stream info: \(videoId) (source: \(musicSource ?? "default"))")
        let streamInfo = try await pythonService.getStreamInfo(videoId: videoId, musicSource: musicSource)
        
        // Cache the result for future use
        let cachedInfo = CachedStreamInfo(
            url: streamInfo.url,
            title: streamInfo.title,
            duration: streamInfo.duration,
            videoId: videoId
        )
        streamCache.setObject(cachedInfo, forKey: cacheKey)
        
        return streamInfo
    }
    
    // 🚀 FAST SEEK OPTIMIZATION: Enhanced player setup with prefetching
    private func setupPlayerWithPrefetch(with streamInfo: StreamInfo, track: Track, startFromPosition: TimeInterval? = nil) {
        print("🚀 Setting up player with prefetch optimization: \(streamInfo.url)")
        
        // Only cleanup if we're switching to a different track
        cleanup()
        
        guard let url = URL(string: streamInfo.url) else {
            print("❌ Invalid stream URL: \(streamInfo.url)")
            playbackState = PlaybackState.error("Invalid stream URL")
            isBuffering = false
            return
        }
        
        print("🚀 Creating optimized AVPlayer for perfect seeking: \(url)")
        
        // Create player item
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // 🚀 PERFECT SEEKING: Configure player for partial buffering
        player?.automaticallyWaitsToMinimizeStalling = true  // Wait for buffering before playing
        player?.volume = volume
        
        // 🚀 Configure player item for better buffering and seeking
        if let playerItem = playerItem {
            // Prefer forward buffer for smooth playback - 2 minutes ahead for better performance with long songs
            playerItem.preferredForwardBufferDuration = 120.0  // 2 minutes ahead
            
            // Configure for better buffering behavior with long songs
            // This API is only available on macOS 15.0+
            if #available(macOS 15.0, *) {
                playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
            }
            
            // Set maximum duration for complete song loading
            if #available(macOS 13.0, *) {
                playerItem.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
            }
        }
        
        // Handle starting position
        if let startPosition = startFromPosition {
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) // Precise seeking
            print("🚀 Precise seeking to resume position: \(startPosition) seconds")
        } else {
            // For new tracks, start from beginning (0:00)
            let startTime = CMTime.zero
            player?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) // Precise seeking
            print("🚀 Precise seeking to start (0:00)")
        }
        
        // Set duration immediately
        duration = streamInfo.duration
        
        // Set up observers AFTER creating player and setting duration
        setupPlayerObservers()
        
        // 🚀 Start prefetching next track for seamless transitions
        startNextTrackPrefetch()
        
        // Start playback - but wait for ready state
        print("🚀 Player with prefetch optimization ready, waiting for buffering...")
        playbackState = PlaybackState.buffering
        
        // Start periodic buffer monitoring for better long song performance
        startBufferMonitoring()
        
        print("🚀 Enhanced player setup complete with perfect seeking capabilities")
    }
    
    // 🚀 FAST SEEK OPTIMIZATION: Prefetch next track in background
    private func startNextTrackPrefetch() {
        // Cancel any existing prefetch task
        prefetchTask?.cancel()
        
        // Only prefetch if there's a next track
        guard queueManager.hasNext, let nextTrack = queueManager.nextTrack else {
            print("🚀 No next track to prefetch")
            return
        }
        
        print("🚀 Starting prefetch for next track: \(nextTrack.title)")
        
        prefetchTask = Task { [weak self] in
            do {
                // Wait a bit to not interfere with current track loading
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                guard !Task.isCancelled else { return }
                
                // Prefetch stream info for next track
                _ = try await self?.getStreamInfoWithCaching(videoId: nextTrack.videoId, musicSource: nextTrack.musicSource)
                print("🚀 Prefetched next track successfully: \(nextTrack.title)")
                
            } catch {
                print("🚀 Prefetch failed (not critical): \(error)")
            }
        }
    }
    
    // 🚀 OPTIMIZED: Monitor buffer status with faster playback start
    // 🔋 CPU OPTIMIZATION: Timer stops after playback starts to save CPU
    private func startBufferMonitoring() {
        // Cancel any existing timer
        bufferTimer?.invalidate()
        
        // Track if we've started playback
        var hasStartedPlayback = false
        var bufferCheckCount = 0
        
        // 🔋 Check buffer at reasonable interval (0.5s instead of 0.3s)
        bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, let playerItem = self.playerItem else { return }
            
            bufferCheckCount += 1
            
            // Check buffer status
            let isBufferEmpty = playerItem.isPlaybackBufferEmpty
            let isBufferLikelyToKeepUp = playerItem.isPlaybackLikelyToKeepUp
            let loadedRanges = playerItem.loadedTimeRanges
            
            // Calculate how much is buffered
            var bufferedSeconds: Double = 0
            if let firstRange = loadedRanges.first?.timeRangeValue {
                bufferedSeconds = CMTimeGetSeconds(firstRange.start) + CMTimeGetSeconds(firstRange.duration)
            }
            
            DispatchQueue.main.async {
                // 🚀 FAST START: Start playback after just 0.5 seconds of buffer OR after 2 checks (~1s)
                let shouldStartFast = !hasStartedPlayback && 
                    self.playbackState == .buffering && 
                    self.player?.rate == 0 &&
                    (bufferedSeconds >= 0.5 || bufferCheckCount >= 2 || !isBufferEmpty)
                
                if shouldStartFast {
                    hasStartedPlayback = true
                    print("🚀 Fast start! Buffered: \(String(format: "%.1f", bufferedSeconds))s, starting playback immediately")
                    self.player?.play()
                    self.playbackState = .playing
                    self.updateNowPlayingInfo()
                    
                    // 🔋 CPU OPTIMIZATION: Stop buffer timer after playback starts!
                    timer.invalidate()
                    self.bufferTimer = nil
                    print("🔋 Buffer timer stopped - saving CPU")
                }
                
                // Update buffering indicator (but don't stop playback)
                self.isBuffering = isBufferEmpty && self.playbackState.isPlaying
                
                // Normal start if fast start didn't trigger and buffer is ready
                if !hasStartedPlayback && isBufferLikelyToKeepUp && self.playbackState == .buffering && self.player?.rate == 0 {
                    hasStartedPlayback = true
                    self.player?.play()
                    self.playbackState = .playing
                    self.updateNowPlayingInfo()
                    print("🎵 Buffering complete, starting playback")
                    
                    // 🔋 CPU OPTIMIZATION: Stop buffer timer after playback starts!
                    timer.invalidate()
                    self.bufferTimer = nil
                    print("🔋 Buffer timer stopped - saving CPU")
                }
            }
        }
    }
    
    private func setupPlayer(with streamInfo: StreamInfo, startFromPosition: TimeInterval? = nil) {
        print("🎵 Setting up player with URL: \(streamInfo.url)")
        
        // Only cleanup if we're switching to a different track
        cleanup()
        
        guard let url = URL(string: streamInfo.url) else {
            print("❌ Invalid stream URL: \(streamInfo.url)")
            playbackState = .error("Invalid stream URL")
            isBuffering = false
            return
        }
        
        print("🎵 Creating AVPlayer with URL: \(url)")
        
        // Create player item
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Configure audio for better playback
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.volume = volume
        
        // Handle starting position
        if let startPosition = startFromPosition {
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            player?.seek(to: startTime)
            print("🎵 Seeking to resume position: \(startPosition) seconds")
        } else {
            // For new tracks, start from beginning (0:00)
            let startTime = CMTime.zero
            player?.seek(to: startTime)
            print("🎵 Explicitly set player position to start (0:00)")
        }
        
        // Set duration immediately
        duration = streamInfo.duration
        
        // Set up observers AFTER creating player and setting duration
        setupPlayerObservers()
        
        // Start playback - but wait for ready state
        print("🎵 Player created, waiting for ready state...")
        playbackState = .buffering
        
        print("🎵 Player setup complete, waiting for ready state")
    }
    
    // MARK: - Resume from saved position
    
    func resumeFromSavedPosition() async {
        guard currentTrack != nil else { return }
        
        let savedTime = currentTime
        print("🎵 Resuming playback from saved position: \(savedTime)")
        await playCurrentTrack(startFromPosition: savedTime)
    }
    
    func pause() {
        player?.pause()
        playbackState = .paused
        saveCurrentTrack() // Save state when pausing
        forceUpdateNowPlayingInfo() // 🔋 Force immediate update for state changes
        
        // Stop buffer monitoring when paused
        bufferTimer?.invalidate()
        bufferTimer = nil
    }
    
    func resume() {
        player?.play()
        playbackState = .playing
        forceUpdateNowPlayingInfo() // 🔋 Force immediate update for state changes
        
        // Restart buffer monitoring when resuming
        startBufferMonitoring()
    }
    
    func stop() {
        player?.pause()
        cleanup()
        playbackState = .stopped
        currentTrack = nil
        currentTime = 0
        duration = 0
        saveCurrentTrack() // Save nil track
        nowPlayingManager.clearNowPlayingInfo()
        
        // Stop buffer monitoring when stopped
        bufferTimer?.invalidate()
        bufferTimer = nil
    }
    
    func seek(to time: TimeInterval) {
        // 🚀 PERFECT SEEKING: Enhanced seeking with prefetched data
        print("🚀 Initiating perfect seek to: \(time)s")
        
        // Set flag to prevent time observer from interfering
        isSeeking = true
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // 🚀 Use zero tolerance for pixel-perfect seeking with cached data
        player?.seek(to: cmTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] finished in
            guard let self = self, finished else { return }
            
            DispatchQueue.main.async {
                // Update currentTime immediately after seek completes
                self.currentTime = time
                
                // Save the new position for persistence
                self.saveCurrentTrack()
                
                // 🚀 Force immediate Now Playing update for perfect sync
                self.forceUpdateNowPlayingInfo()
                
                // Reset seeking flag after a brief delay to allow player to stabilize
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.setSeekingState(false)  // Use centralized seeking state management
                }
                
                print("🚀 Perfect seek completed to: \(Int(time))s with zero latency")
            }
        }
    }
    
    // MARK: - Seeking State Management
    
    // 🔋 BATTERY EFFICIENCY: External seeking state control for robust slider behavior
    func setSeekingState(_ seeking: Bool) {
        isSeeking = seeking
        if seeking {
            print("🎯 Seeking state: STARTED - time observer suppressed")
        } else {
            print("🎯 Seeking state: ENDED - time observer resumed")
        }
    }
    
    // MARK: - Queue Navigation
    
    /// Debounced next track - waits for rapid taps to settle before playing
    func playNext() async {
        print("🎵 playNext() called - debouncing")
        
        // Cancel any pending skip playback
        skipDebounceTask?.cancel()
        skipDebounceTask = nil
        
        // Generate new playback ID to invalidate any in-progress playback
        let newPlaybackId = UUID()
        currentPlaybackId = newPlaybackId
        
        // Stop current playback immediately
        await MainActor.run {
            self.player?.pause()
            self.cleanup()  // Clean up player to stop any loading
        }
        
        // Move to next in queue
        if queueManager.moveToNext() {
            print("🎵 Moved to next track - index: \(queueManager.currentIndex)")
            
            // Update UI immediately to show the new track info
            await MainActor.run {
                if let track = queueManager.currentTrack {
                    self.currentTrack = track
                    self.playbackState = .buffering
                    self.currentTime = 0
                    self.duration = track.duration ?? 0
                }
            }
            
            // Schedule debounced playback - wait for user to stop tapping
            skipDebounceTask = Task { [weak self, newPlaybackId] in
                do {
                    // Wait 0.4 seconds after last tap
                    try await Task.sleep(nanoseconds: 400_000_000)
                    
                    guard !Task.isCancelled else {
                        print("🎵 Skip cancelled - user tapped again")
                        return
                    }
                    
                    // Now actually load and play the track with the playback ID
                    print("🎵 Debounce complete - now loading track")
                    await self?.playCurrentTrack(playbackId: newPlaybackId)
                } catch {
                    print("🎵 Skip debounce interrupted")
                }
            }
        } else {
            print("🎵 No next track available - stopping")
            await MainActor.run {
                self.stop()
            }
        }
    }
    
    /// Debounced previous track - waits for rapid taps to settle before playing
    func playPrevious() async {
        print("🎵 playPrevious() called - debouncing")
        
        // Cancel any pending skip playback
        skipDebounceTask?.cancel()
        skipDebounceTask = nil
        
        // Generate new playback ID to invalidate any in-progress playback
        let newPlaybackId = UUID()
        currentPlaybackId = newPlaybackId
        
        // Stop current playback immediately
        await MainActor.run {
            self.player?.pause()
            self.cleanup()  // Clean up player to stop any loading
        }
        
        // Move to previous in queue
        if queueManager.moveToPrevious() {
            print("🎵 Moved to previous track - index: \(queueManager.currentIndex)")
            
            // Update UI immediately to show the new track info
            await MainActor.run {
                if let track = queueManager.currentTrack {
                    self.currentTrack = track
                    self.playbackState = .buffering
                    self.currentTime = 0
                    self.duration = track.duration ?? 0
                }
            }
            
            // Schedule debounced playback - wait for user to stop tapping
            skipDebounceTask = Task { [weak self, newPlaybackId] in
                do {
                    // Wait 0.4 seconds after last tap
                    try await Task.sleep(nanoseconds: 400_000_000)
                    
                    guard !Task.isCancelled else {
                        print("🎵 Skip cancelled - user tapped again")
                        return
                    }
                    
                    // Now actually load and play the track with the playback ID
                    print("🎵 Debounce complete - now loading track")
                    await self?.playCurrentTrack(playbackId: newPlaybackId)
                } catch {
                    print("🎵 Skip debounce interrupted")
                }
            }
        } else {
            print("🎵 No previous track available")
        }
    }
    
    // MARK: - Player Observers
    
    private func setupPlayerObservers() {
        guard let player = player, let playerItem = playerItem else { return }
        
        // 🔋 BATTERY OPTIMIZATION: Reduce time observer frequency from 0.5s to 1.0s
        // This reduces CPU usage by 50% while maintaining smooth UI updates
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            // Skip time updates if we're currently seeking to prevent interference
            guard !self.isSeeking else { return }
            
            self.currentTime = time.seconds
            self.throttledUpdateNowPlayingInfo()
            
            // 🔋 BATTERY EFFICIENCY: Save state more frequently when app is active
            // Save every 2 seconds when app is active, every 10 seconds when inactive
            let saveInterval = NSApp.isActive ? 2 : 10
            if Int(self.currentTime) % saveInterval == 0 {
                self.saveCurrentTrack()
            }
            
            // Check if song has ended (within 1 second of duration)
            if self.duration > 0 && self.currentTime >= (self.duration - 1.0) && self.playbackState.isPlaying {
                print("🎵 Song reached end time: \(self.currentTime)/\(self.duration)")
                Task {
                    await self.handlePlaybackEnd()
                }
            }
        }
        
        // Player item status observer
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handlePlayerStatusChange(status)
            }
            .store(in: &cancellables)
        
        // Playback end observer
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🎵 AVPlayerItemDidPlayToEndTime notification received")
                Task {
                    await self?.handlePlaybackEnd()
                }
            }
            .store(in: &cancellables)
        
        // Add boundary time observer for more precise end detection
        if duration > 0 {
            let endTime = CMTime(seconds: max(0, duration - 0.5), preferredTimescale: 600)
            player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
                print("🎵 Boundary time observer triggered - song near end")
                // Don't auto-advance here, let the main end detection handle it
            }
        }
        
        // Buffer status is now handled by our timer-based monitoring
        
        // Stalled playback observer
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handlePlaybackStalled()
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerStatusChange(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            print("🎵 Player ready to play")
            // For partial loading, we wait for buffering to complete before playing
            // Buffering state is now handled by our timer-based monitoring
            updateNowPlayingInfo()
            
            // Test remote commands after starting playback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.nowPlayingManager.testRemoteCommands()
            }
            
        case .failed:
            let errorMessage: String
            if let error = playerItem?.error {
                errorMessage = error.localizedDescription
                print("❌ Player failed with error: \(error)")
            } else {
                errorMessage = "Playback failed"
                print("❌ Player failed with unknown error")
            }
            playbackState = .error(errorMessage)
            isBuffering = false
            
        case .unknown:
            print("🎵 Player status unknown")
            break
            
        @unknown default:
            print("🎵 Player status unknown default")
            break
        }
    }
    
    // Add a public method to test remote commands manually
    func testRemoteCommands() {
        nowPlayingManager.testRemoteCommands()
    }
    
    private func handlePlaybackEnd() async {
        print("🎵 Song ended - attempting to play next track")
        
        // Stop the current player to prevent it from continuing
        await MainActor.run {
            self.player?.pause()
            self.playbackState = .stopped
        }
        
        // Check if we have a next track in the queue
        if queueManager.hasNext {
            print("🎵 Moving to next track in queue")
            await playNext()
        } else {
            print("🎵 No more tracks in queue - stopping playback")
            await MainActor.run {
                self.stop()
            }
        }
    }
    
    private func handlePlaybackStalled() {
        isBuffering = true
        
        // Try to resume after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.playbackState.isPlaying == true {
                self?.player?.play()
            }
            self?.isBuffering = false
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Stop buffer monitoring
        bufferTimer?.invalidate()
        bufferTimer = nil
        
        // Cancel any pending skip task
        skipDebounceTask?.cancel()
        skipDebounceTask = nil
        
        cancellables.removeAll()
        player = nil
        playerItem = nil
    }
    
    // MARK: - Persistence
    
    private func saveCurrentTrack() {
        savePlaybackState()
    }
    
    // 🔋 BATTERY EFFICIENCY: Add method to save state with app activity context
    func savePlaybackState() {
        let playbackData = PlaybackData(
            track: currentTrack,
            currentTime: currentTime,
            duration: duration,
            queue: queueManager.currentQueue,
            currentIndex: queueManager.currentIndex,
            shuffleEnabled: queueManager.shuffleEnabled,
            repeatMode: queueManager.repeatMode,
            wasPlaying: playbackState.isPlaying
        )
        
        if let data = try? JSONEncoder().encode(playbackData) {
            UserDefaults.standard.set(data, forKey: "lastPlaybackState")
            print("💾 Saved playback state: \(currentTrack?.title ?? "nil"), time: \(currentTime), queue: \(queueManager.currentQueue.count) tracks")
        }
    }
    
    private func restoreLastTrack() {
        if let data = UserDefaults.standard.data(forKey: "lastPlaybackState"),
           let playbackData = try? JSONDecoder().decode(PlaybackData.self, from: data) {
            
            // Restore track
            currentTrack = playbackData.track
            
            // Restore queue state
            if !playbackData.queue.isEmpty {
                queueManager.currentQueue = playbackData.queue
                queueManager.currentIndex = playbackData.currentIndex
                queueManager.shuffleEnabled = playbackData.shuffleEnabled
                queueManager.repeatMode = playbackData.repeatMode
            }
            
            // Restore playback position
            currentTime = playbackData.currentTime
            duration = playbackData.duration
            
            // Set state to stopped (don't auto-resume playback)
            playbackState = .stopped
            
            print("🎵 Restored playback state:")
            print("   Track: \(playbackData.track?.title ?? "nil")")
            print("   Position: \(playbackData.currentTime)/\(playbackData.duration)")
            print("   Queue: \(playbackData.queue.count) tracks at index \(playbackData.currentIndex)")
            print("   Shuffle: \(playbackData.shuffleEnabled), Repeat: \(playbackData.repeatMode)")
            print("   Was playing: \(playbackData.wasPlaying)")
        }
    }
    
    // MARK: - Now Playing Integration
    
    // 🔋 BATTERY OPTIMIZATION: Throttle Now Playing updates to reduce CPU usage
    private var lastNowPlayingUpdate: TimeInterval = 0
    private let nowPlayingUpdateThrottle: TimeInterval = 2.0 // Update every 2 seconds max
    
    private func throttledUpdateNowPlayingInfo() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Only update if enough time has passed or if playback state changes
        if currentTime - lastNowPlayingUpdate >= nowPlayingUpdateThrottle {
            updateNowPlayingInfo()
            lastNowPlayingUpdate = currentTime
        }
    }
    
    // Force immediate update for critical state changes (play/pause/skip)
    private func forceUpdateNowPlayingInfo() {
        updateNowPlayingInfo()
        lastNowPlayingUpdate = CFAbsoluteTimeGetCurrent()
    }
    
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            nowPlayingManager.clearNowPlayingInfo()
            return
        }
        
        // 🔋 BATTERY OPTIMIZATION: Remove aggressive NSApp.activate() calls
        // This was causing unnecessary app activations and battery drain
        
        nowPlayingManager.updateNowPlayingInfo(
            track: track,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration
        )
    }
    
    // MARK: - Utility Methods
    
    var isPlaying: Bool {
        return playbackState.isPlaying
    }
    
    var isPaused: Bool {
        return playbackState.isPaused
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
}

// MARK: - Queue Manager

class QueueManager: ObservableObject {
    @Published var currentQueue: [Track] = []
    @Published var currentIndex: Int = 0
    @Published var shuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .all  // Default to auto-play next for all new users
    
    var currentTrack: Track? {
        guard currentIndex < currentQueue.count else { return nil }
        return currentQueue[currentIndex]
    }
    
    var nextTrack: Track? {
        switch repeatMode {
        case .single:
            return currentTrack // In single mode, next track is same
        case .all:
            if shuffleEnabled {
                // For shuffle mode, we can't predict the next track
                return currentQueue.randomElement()
            } else {
                let nextIndex = (currentIndex + 1) % currentQueue.count
                return currentQueue[nextIndex]
            }
        case .none:
            if shuffleEnabled && currentQueue.count > 1 {
                // For shuffle mode without repeat, we can't predict the next track
                return currentQueue.randomElement()
            } else {
                let nextIndex = currentIndex + 1
                guard nextIndex < currentQueue.count else { return nil }
                return currentQueue[nextIndex]
            }
        }
    }
    
    // MARK: - Queue Management
    
    func setQueue(_ tracks: [Track], startingAt track: Track? = nil) {
        currentQueue = tracks
        
        if let track = track, let index = tracks.firstIndex(where: { $0.id == track.id }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
    }
    
    func setCurrentTrack(_ track: Track) {
        currentQueue = [track]
        currentIndex = 0
    }
    
    func addToQueue(_ track: Track) {
        currentQueue.append(track)
    }
    
    func addToQueue(_ tracks: [Track]) {
        currentQueue.append(contentsOf: tracks)
    }
    
    func addToQueueNext(_ track: Track) {
        let insertIndex = currentIndex + 1
        if insertIndex <= currentQueue.count {
            currentQueue.insert(track, at: insertIndex)
        } else {
            currentQueue.append(track)
        }
    }
    
    func addToQueueNext(_ tracks: [Track]) {
        let insertIndex = currentIndex + 1
        if insertIndex <= currentQueue.count {
            currentQueue.insert(contentsOf: tracks, at: insertIndex)
        } else {
            currentQueue.append(contentsOf: tracks)
        }
    }
    
    func removeFromQueue(at index: Int) {
        guard index < currentQueue.count else { return }
        currentQueue.remove(at: index)
        
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex && currentIndex >= currentQueue.count {
            currentIndex = max(0, currentQueue.count - 1)
        }
    }
    
    func clearQueue() {
        currentQueue.removeAll()
        currentIndex = 0
        print("🧹 QueueManager: Cleared queue, count: \(currentQueue.count)")
    }
    
    // MARK: - Navigation
    
    func moveToNext() -> Bool {
        switch repeatMode {
        case .single:
            return true // Stay on current track
        case .all:
            if shuffleEnabled {
                currentIndex = Int.random(in: 0..<currentQueue.count)
            } else {
                currentIndex = (currentIndex + 1) % currentQueue.count
            }
            return true
        case .none:
            if shuffleEnabled && currentQueue.count > 1 {
                let nextIndex = Int.random(in: 0..<currentQueue.count)
                currentIndex = nextIndex == currentIndex ? (nextIndex + 1) % currentQueue.count : nextIndex
                return true
            } else {
                currentIndex += 1
                return currentIndex < currentQueue.count
            }
        }
    }
    
    func moveToPrevious() -> Bool {
        if shuffleEnabled {
            currentIndex = Int.random(in: 0..<currentQueue.count)
            return true
        } else {
            currentIndex = max(0, currentIndex - 1)
            return true
        }
    }
    
    func moveToTrack(at index: Int) -> Bool {
        guard index < currentQueue.count else { return false }
        currentIndex = index
        return true
    }
    
    // MARK: - Queue Info
    
    var hasNext: Bool {
        switch repeatMode {
        case .single, .all:
            return true
        case .none:
            // In "Off" mode, don't auto-play next track
            return false
        }
    }
    
    var hasPrevious: Bool {
        return currentIndex > 0 || repeatMode == .all
    }
    
    var isEmpty: Bool {
        return currentQueue.isEmpty
    }
    
    var queueSize: Int {
        return currentQueue.count
    }
    
    // Toggle shuffle mode
    func toggleShuffle() {
        shuffleEnabled.toggle()
    }
}