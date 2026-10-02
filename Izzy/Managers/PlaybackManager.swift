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

// MARK: - Track Change Notification

extension Notification.Name {
    /// 📢 Posted on the main queue whenever PlaybackManager starts a NEW track.
    /// userInfo["track"] holds the current Track. Not posted when the same
    /// videoId resumes or retries.
    static let izzyTrackChanged = Notification.Name("izzyTrackChanged")
}

// MARK: - Playback Manager

// 🚀 FAST SEEK OPTIMIZATION: Cached stream information for instant seeking
private class CachedStreamInfo {
    let streamInfo: StreamInfo
    let cachedTime: Date
    let videoId: String
    
    init(streamInfo: StreamInfo, videoId: String) {
        self.streamInfo = streamInfo
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
    @Published var showLyrics: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var isBuffering: Bool = false
    /// Quality actually being played (e.g. DOLBY_ATMOS, HI_RES_LOSSLESS), which
    /// can differ from the catalogue quality when a tier falls back.
    @Published var currentStreamQuality: String?
    @Published var currentStreamQualityInfo: String?
    @Published var volume: Float = 0.7 {
        didSet {
            player?.volume = volume
            UserDefaults.standard.set(volume, forKey: "playerVolume")
        }
    }
    // 📻 AUTOPLAY RADIO: When the queue runs dry, keep playing tracks similar
    // to the one that just ended. SettingsView writes the same key via
    // @AppStorage, so the live value is re-read from UserDefaults when the
    // queue actually exhausts.
    @Published var autoplayRadio: Bool = false {
        didSet {
            UserDefaults.standard.set(autoplayRadio, forKey: "autoplayRadioEnabled")
        }
    }
    // 😴 SLEEP TIMER: nil = off. `sleepAtTrackEnd` pauses when the current
    // track finishes instead of using a wall-clock timer.
    @Published var sleepTimerEndDate: Date?
    @Published var sleepAtTrackEnd: Bool = false
    // ⏩ PLAYBACK SPEED: Persisted playback rate. AVPlayer's rate preserves
    // pitch on Apple platforms, so 1.5x audio stays natural.
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(playbackSpeed, forKey: "playbackSpeed")
        }
    }

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    // Retained for the life of an HLS (Tidal Hi-Res / Atmos) item: the asset's
    // resource loader only holds its delegate weakly.
    private var hlsPlaylistLoader: TidalHLSPlaylistLoader?
    // Retained for the life of a proxied FLAC item (same reason).
    private var byteRangeLoader: TidalByteRangeLoader?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    // Subscriptions scoped to the current AVPlayerItem. Kept separate from
    // `cancellables` because cleanup() tears these down on every track change —
    // and it used to clear `cancellables` wholesale, which also destroyed the
    // remote-command handlers registered once in init(). That silently killed
    // every macOS Now Playing / Control Center button after the first track.
    private var playerCancellables = Set<AnyCancellable>()
    private var isSeeking = false  // Flag to prevent time updates during seeking
    
    // 🚀 FAST SEEK OPTIMIZATION: Advanced caching for instant seeking
    private var streamCache = NSCache<NSString, CachedStreamInfo>()
    private var prefetchTask: Task<Void, Never>?
    private var bufferTimer: Timer?
    
    // 🎵 DEBOUNCE: Skip navigation debounce for rapid next/previous taps
    private var skipDebounceTask: Task<Void, Never>?
    private var currentPlaybackId: UUID = UUID()  // Track which playback request is current

    // 😴 SLEEP TIMER state: one-shot timer + fade bookkeeping. `isSleepFading`
    // makes a natural track end during the fade a no-op; the handled latch
    // keeps the second end detection (time observer + item-end notification
    // can both fire) from advancing the queue after a sleep-at-track-end pause.
    private var sleepTimer: Timer?
    private var isSleepFading = false
    private var isSleepTrackEndHandled = false
    
    private let queueManager = QueueManager()
    private let pythonService = PythonServiceManager.shared
    private let nowPlayingManager = NowPlayingManager.shared
    
    private init() {
        // Load saved volume
        let savedVolume = UserDefaults.standard.float(forKey: "playerVolume")
        if savedVolume > 0 {
            volume = savedVolume
        }
        // 📻 Load saved autoplay radio + ⏩ playback speed
        autoplayRadio = UserDefaults.standard.bool(forKey: "autoplayRadioEnabled")
        let savedSpeed = UserDefaults.standard.double(forKey: "playbackSpeed")
        if savedSpeed > 0 {
            playbackSpeed = savedSpeed
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

        NotificationCenter.default.publisher(for: .remoteTogglePlayPauseCommand)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                print("🎮 PlaybackManager received remote toggle play/pause command")
                if self.isPlaying {
                    self.pause()
                } else {
                    self.resume()
                }
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
    
    // MARK: - Track Change Notification
    
    // 📢 Central setter for `currentTrack`: posts .izzyTrackChanged on the main
    // queue whenever the track actually changes. Resume/retry of the same
    // videoId stays silent. Must be called on the main thread.
    private func setCurrentTrackAndNotify(_ track: Track?) {
        let isNewTrack = track?.videoId != currentTrack?.videoId
        currentTrack = track
        if isNewTrack, let track = track {
            NotificationCenter.default.post(name: .izzyTrackChanged, object: nil, userInfo: ["track": track])
        }
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
    
    // 🎵 OFFLINE: Play a local audio file directly through AVPlayer — no
    // Python service involved. The file URL is stored as the track's videoId
    // (url.absoluteString) so the regular playback path works end to end.
    func playLocalFile(url: URL, title: String? = nil, artist: String? = nil) {
        print("🎵 playLocalFile() called for: \(url.lastPathComponent)")
        
        let track = Track(
            title: title ?? url.deletingPathExtension().lastPathComponent,
            artist: artist ?? "Unknown Artist",
            duration: 0,
            videoId: url.absoluteString,
            musicSource: "local"
        )
        
        // Make it the current queue entry, then reuse the regular playback path
        // (which handles the local branch, UI state, observers and Now Playing).
        queueManager.setCurrentTrack(track)
        Task {
            await playCurrentTrack()
        }
    }
    
    func playCurrentTrack(startFromPosition: TimeInterval? = nil, playbackId: UUID? = nil) async {
        // 😴 New playback request — re-enable end-of-track handling in case the
        // previous track was parked by a sleep-at-track-end pause.
        isSleepTrackEndHandled = false
        
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
            self.setCurrentTrackAndNotify(track)
            self.playbackState = PlaybackState.buffering
            self.isBuffering = true
            
            // Only reset time for new tracks, not when resuming
            if let startPosition = startFromPosition {
                self.currentTime = startPosition
                anchorSmoothTime()
                print("🎵 Resuming from position: \(startPosition)")
            } else {
                self.currentTime = 0  // Reset to start from beginning for new tracks
                anchorSmoothTime()
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
        
        // 🎵 OFFLINE: Local files play directly through AVPlayer — resolve the
        // file URL from videoId (stored as url.absoluteString) and skip stream
        // resolution + the Python service entirely.
        if track.musicSource == "local" {
            guard let fileURL = URL(string: track.videoId), fileURL.isFileURL else {
                print("❌ Invalid local file path: \(track.videoId)")
                await MainActor.run {
                    self.playbackState = .error("Invalid local file")
                    self.isBuffering = false
                }
                return
            }
            await MainActor.run {
                self.setupPlayerForLocalFile(fileURL, track: track, startFromPosition: startFromPosition)
            }
            return
        }
        
        // Check if video ID is valid
        guard !track.videoId.isEmpty else {
            await MainActor.run {
                self.playbackState = .error("Invalid video ID")
                self.isBuffering = false
            }
            return
        }
        
        // ⚡ TIDAL FAST PATH: the direct lossless FLAC URL is deterministic
        // (Monochrome's /track/<id>), so the player starts fetching audio
        // IMMEDIATELY — in parallel with stream resolution, which then only
        // reconciles the quality badge and duration. Real-world players never
        // serialize metadata resolution ahead of the media fetch. Atmos is
        // excluded: it needs the pool manifests and the sequential path.
        if track.musicSource == "tidal", !TidalSettings.dolbyAtmos {
            // Keep in sync with TidalService.PRIMARY_API in ytmusic_service.py.
            let directURL = "https://tracks.monochrome.st/track/\(track.videoId)"
            var fastStream = StreamInfo(
                url: directURL,
                title: track.title,
                duration: track.duration,
                quality: "LOSSLESS",
                mimeType: "audio/flac"
            )
            fastStream.needsByteProxy = true
            print("⚡ Tidal fast path: starting player on deterministic URL")
            await MainActor.run {
                guard expectedId == self.currentPlaybackId else { return }
                self.setupPlayerWithPrefetch(with: fastStream, track: track, startFromPosition: startFromPosition)
            }
            
            // Metadata reconciliation in parallel — never blocks audio.
            let reconciled = try? await getStreamInfoWithCaching(videoId: track.videoId, musicSource: "tidal")
            await MainActor.run {
                guard expectedId == self.currentPlaybackId, let reconciled else { return }
                if reconciled.duration > 0, abs(reconciled.duration - self.duration) > 0.5 {
                    self.duration = reconciled.duration
                }
                if let q = reconciled.quality { self.currentStreamQuality = q }
                if let qi = reconciled.qualityInfo { self.currentStreamQualityInfo = qi }
                print("⚡ Tidal fast path reconciled: \(reconciled.qualityInfo ?? reconciled.quality ?? "stream")")
            }
            return
        }
        
        do {
            print("🎵 Getting stream info for video ID: \(track.videoId)")
            
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
        // Tidal streams also depend on the quality / Dolby Atmos settings.
        let settingsSignature = musicSource == "tidal" ? "_\(TidalSettings.cacheSignature)" : ""
        let cacheKey = NSString(string: "\(videoId)_\(musicSource ?? "default")\(settingsSignature)")
        
        // Check if we have cached stream info that hasn't expired
        if let cached = streamCache.object(forKey: cacheKey), !cached.isExpired {
            print("🚀 Using cached stream info for instant playback: \(videoId)")
            return cached.streamInfo
        }
        
        // Fetch fresh stream info with the track's music source
        print("🚀 Fetching fresh stream info: \(videoId) (source: \(musicSource ?? "default"))")
        let streamInfo = try await pythonService.getStreamInfo(videoId: videoId, musicSource: musicSource)
        
        // Cache the result for future use
        let cachedInfo = CachedStreamInfo(streamInfo: streamInfo, videoId: videoId)
        streamCache.setObject(cachedInfo, forKey: cacheKey)
        
        return streamInfo
    }
    
    // 🚀 FAST SEEK OPTIMIZATION: Enhanced player setup with prefetching
    private func setupPlayerWithPrefetch(with streamInfo: StreamInfo, track: Track, startFromPosition: TimeInterval? = nil) {
        print("🚀 Setting up player with prefetch optimization: \(streamInfo.url)")
        
        // Only cleanup if we're switching to a different track
        cleanup()
        
        guard let item = makePlayerItem(for: streamInfo, trackId: track.videoId) else {
            print("❌ Invalid stream URL: \(streamInfo.url)")
            playbackState = PlaybackState.error("Invalid stream URL")
            isBuffering = false
            return
        }
        
        print("🚀 Creating optimized AVPlayer for perfect seeking")
        
        // Create player item
        playerItem = item
        player = AVPlayer(playerItem: playerItem)
        
        // 🚀 Buffering is governed by our own fast-start monitor; AVPlayer's
        // internal wait would stack a second delay on top of it.
        player?.automaticallyWaitsToMinimizeStalling = false
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
        // 🎚️ 100ms pre-tolerance: exact-sample seeks wait for the precise
        // packet over the network before the first audio byte lands.
        if let startPosition = startFromPosition {
            let startTime = CMTime(seconds: startPosition, preferredTimescale: 600)
            player?.seek(to: startTime, toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600), toleranceAfter: .zero)
            print("🚀 Seeking to resume position: \(startPosition) seconds")
        } else {
            let startTime = CMTime.zero
            player?.seek(to: startTime, toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600), toleranceAfter: .zero)
            print("🚀 Seeking to start (0:00)")
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
    
    /// Builds the player item for a resolved stream. Segmented Tidal streams
    /// (Hi-Res FLAC, Dolby Atmos) arrive as an HLS playlist and play through
    /// TidalHLSPlaylistLoader; proxied FLAC streams go through
    /// TidalByteRangeLoader; everything else is a plain progressive URL.
    private func makePlayerItem(for streamInfo: StreamInfo, trackId: String) -> AVPlayerItem? {
        hlsPlaylistLoader = nil
        byteRangeLoader = nil
        currentStreamQuality = streamInfo.quality
        currentStreamQualityInfo = streamInfo.qualityInfo

        if let playlist = streamInfo.hlsPlaylist, !playlist.isEmpty,
           let hls = TidalHLSPlaylistLoader.makeAsset(playlist: playlist, trackId: trackId) {
            hlsPlaylistLoader = hls.1
            print("🎧 Tidal \(streamInfo.qualityInfo ?? streamInfo.quality ?? "stream") via HLS")
            return AVPlayerItem(asset: hls.0)
        }

        guard let url = URL(string: streamInfo.url) else { return nil }
        if streamInfo.needsByteProxy == true,
           let proxy = TidalByteRangeLoader.makeAsset(remoteURL: url, trackId: trackId) {
            byteRangeLoader = proxy.1
            print("🎧 Tidal \(streamInfo.qualityInfo ?? streamInfo.quality ?? "stream") via byte proxy")
            return AVPlayerItem(asset: proxy.0)
        }
        return AVPlayerItem(url: url)
    }
    
    // 🎵 OFFLINE: Player setup for a local file. Reuses the exact streamed setup
    // path (setupPlayerWithPrefetch) with a synthesized StreamInfo — the
    // plain-URL branch of makePlayerItem() wraps the file URL in a plain
    // AVPlayerItem, so no Python service call happens anywhere in this path.
    // (Embedded artwork extraction is skipped on purpose: Track.thumbnailURL is
    // a remote-URL string today.)
    private func setupPlayerForLocalFile(_ fileURL: URL, track: Track, startFromPosition: TimeInterval? = nil) {
        print("🎵 Setting up local file playback: \(fileURL.lastPathComponent)")
        
        let streamInfo = StreamInfo(url: fileURL.absoluteString, title: track.title, duration: 0, quality: "LOCAL")
        setupPlayerWithPrefetch(with: streamInfo, track: track, startFromPosition: startFromPosition)
        
        // Duration isn't known up front for local files — load it from the asset
        // so end-of-track detection and the progress bar work.
        let asset = AVURLAsset(url: fileURL)
        Task { [weak self] in
            do {
                let seconds = try await asset.load(.duration).seconds
                await MainActor.run {
                    guard let self = self,
                          self.currentTrack?.videoId == track.videoId,
                          seconds.isFinite, seconds > 0 else { return }
                    self.duration = seconds
                    self.saveCurrentTrack()
                    self.forceUpdateNowPlayingInfo()
                }
            } catch {
                print("⚠️ Failed to load local file duration: \(error)")
            }
        }
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
        
        // 🎵 OFFLINE: Local files have no stream info to prefetch
        guard nextTrack.musicSource != "local" else {
            print("🚀 Next track is a local file - nothing to prefetch")
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
        var bufferEmptySince: Date?
        
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
                    self.isBuffering = false  // clear the pre-play buffering state
                    self.applyPlaybackSpeed()
                    self.anchorSmoothTime()  // 🎤 fresh lyrics clock anchor
                    self.updateNowPlayingInfo()
                    
                    // 🔋 CPU OPTIMIZATION: Stop buffer timer after playback starts!
                    timer.invalidate()
                    self.bufferTimer = nil
                    print("🔋 Buffer timer stopped - saving CPU")
                }
                
                // Update buffering indicator with a debounce: a transient
                // buffer-empty while playing is normal (proxied FLAC arrives
                // in chunks) and must not flip the transport button into a
                // spinner — only an empty buffer persisting ~1.5s counts.
                if self.playbackState.isPlaying {
                    if isBufferEmpty {
                        if bufferEmptySince == nil { bufferEmptySince = Date() }
                        if let since = bufferEmptySince,
                           Date().timeIntervalSince(since) >= 1.5 {
                            self.isBuffering = true
                        }
                    } else {
                        bufferEmptySince = nil
                        self.isBuffering = false
                    }
                } else {
                    bufferEmptySince = nil
                }

                // 🔋 Healthy playback: the monitoring job is done — stop the
                // timer. Stall recovery restarts it if the stream stalls.
                if self.playbackState.isPlaying && !isBufferEmpty && !self.isBuffering {
                    hasStartedPlayback = true
                    timer.invalidate()
                    self.bufferTimer = nil
                }
                
                // Normal start if fast start didn't trigger and buffer is ready
                if !hasStartedPlayback && isBufferLikelyToKeepUp && self.playbackState == .buffering && self.player?.rate == 0 {
                    hasStartedPlayback = true
                    self.player?.play()
                    self.playbackState = .playing
                    self.isBuffering = false  // clear the pre-play buffering state
                    self.applyPlaybackSpeed()
                    self.anchorSmoothTime()  // 🎤 fresh lyrics clock anchor
                    self.updateNowPlayingInfo()
                    print("🎵 Buffering complete, starting playback")
                    
                    // 🔋 CPU OPTIMIZATION: Stop buffer timer after playback starts!
                    timer.invalidate()
                    self.bufferTimer = nil
                    print("🔋 Buffer timer stopped - saving CPU")
                }
            }
        }
        // Buffer polling is a heuristic, not a deadline. Tolerance lets the
        // scheduler batch these fires with other work instead of forcing an
        // exact wakeup twice a second while a track spins up.
        bufferTimer?.tolerance = 0.15
    }
    
    private func setupPlayer(with streamInfo: StreamInfo, startFromPosition: TimeInterval? = nil) {
        print("🎵 Setting up player with URL: \(streamInfo.url)")
        
        // Only cleanup if we're switching to a different track
        cleanup()
        
        guard let item = makePlayerItem(for: streamInfo, trackId: currentTrack?.videoId ?? "track") else {
            print("❌ Invalid stream URL: \(streamInfo.url)")
            playbackState = .error("Invalid stream URL")
            isBuffering = false
            return
        }
        
        print("🎵 Creating AVPlayer for: \(streamInfo.url)")
        
        // Create player item
        playerItem = item
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
    
    // MARK: - Sleep Timer
    
    // 😴 Start a one-shot wall-clock sleep timer. When it fires, the player
    // volume fades to 0 over ~5 seconds and playback pauses — never advancing
    // the queue or triggering radio.
    func startSleepTimer(minutes: Int) {
        guard minutes > 0 else { return }
        sleepTimer?.invalidate()
        // 😴 Abort any in-flight fade from a previous timer
        if isSleepFading {
            isSleepFading = false
            player?.volume = volume
        }
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepAtTrackEnd = false
        
        let interval = TimeInterval(minutes * 60)
        sleepTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.handleSleepTimerFired()
        }
        print("😴 Sleep timer started: \(minutes) minutes")
    }
    
    // 😴 Pause once the current track finishes (no wall-clock timer).
    func startSleepTimerAtTrackEnd() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
        sleepAtTrackEnd = true
        print("😴 Sleep timer: pause at end of current track")
    }
    
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
        sleepAtTrackEnd = false
        
        // 😴 If a fade is mid-flight, stop it and restore the user volume.
        if isSleepFading {
            isSleepFading = false
            player?.volume = volume
        }
        print("😴 Sleep timer cancelled")
    }
    
    private func handleSleepTimerFired() {
        sleepTimer = nil
        sleepTimerEndDate = nil
        print("😴 Sleep timer fired")
        
        guard let player = player else {
            print("😴 No player - sleep timer done")
            return
        }
        let isActive: Bool
        switch playbackState {
        case .playing, .buffering: isActive = true
        default: isActive = false
        }
        guard isActive else {
            print("😴 Playback not active - sleep timer done")
            return
        }
        
        // 😴 Fade player volume to 0 over ~5 seconds, then pause. The user's
        // stored volume (`volume`) is untouched — we drive player?.volume
        // directly and restore it afterwards.
        isSleepFading = true
        let startVolume = player.volume
        let fadeDuration = 5.0
        let steps = 50
        Task { [weak self] in
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(fadeDuration / Double(steps) * 1_000_000_000))
                guard let self = self, self.isSleepFading else { return }
                let fraction = Double(step) / Double(steps)
                let fadedVolume = startVolume * Float(1.0 - fraction)
                await MainActor.run {
                    self.player?.volume = max(0, fadedVolume)
                }
            }
            await MainActor.run { [weak self] in
                self?.finishSleepFade()
            }
        }
    }
    
    private func finishSleepFade() {
        isSleepFading = false
        // 😴 Pause directly — never route through handlePlaybackEnd, so the
        // radio/next-track logic can't fire from a sleep pause.
        pause()
        player?.volume = volume  // Restore the stored user volume
        print("😴 Sleep timer: playback paused")
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
        // 😴 A manual resume after a sleep-at-track-end pause opts back into
        // normal end-of-track handling.
        isSleepTrackEndHandled = false
        player?.play()
        playbackState = .playing
        // 🎤 Time observer ticks skip while paused — re-anchor the smooth
        // lyrics clock so the first seconds after a resume don't extrapolate
        // from a stale anchor (lyrics would jump ahead ~2s).
        anchorSmoothTime()
        applyPlaybackSpeed()
        forceUpdateNowPlayingInfo() // 🔋 Force immediate update for state changes
        
        // Restart buffer monitoring when resuming
        startBufferMonitoring()
    }
    
    // ⏩ PLAYBACK SPEED: Update the stored speed and apply it to a live player
    // immediately. When paused, the player's rate is 0 — we don't fight that;
    // the speed is re-applied when playback starts again. Note: AVPlayer's rate
    // preserves pitch on Apple platforms, so sped-up audio stays natural.
    func setPlaybackSpeed(_ s: Double) {
        let clamped = min(max(s, 0.25), 4.0)
        playbackSpeed = clamped
        if isPlaying {
            player?.rate = Float(clamped)
        }
        print("⏩ Playback speed set to \(clamped)x")
    }
    
    // ⏩ Apply the persisted playback rate to a running player (no-op while
    // paused — rate is 0 there, and resume()/buffer-start re-applies it).
    private func applyPlaybackSpeed() {
        guard playbackState.isPlaying else { return }
        player?.rate = Float(playbackSpeed)
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
        
        // 😴 Stopping playback also ends any pending sleep timer
        cancelSleepTimer()
    }
    
    /// 🎚️ Display-only position update while the user is dragging the seek
    /// bar: the time label and thumb track the finger live; the real seek
    /// fires on release. The time observer is suppressed while seeking, so
    /// nothing fights the preview.
    func previewSeek(to time: TimeInterval) {
        currentTime = time
        anchorSmoothTime()
    }
    
    func seek(to time: TimeInterval) {
        // 🚀 PERFECT SEEKING: Enhanced seeking with prefetched data
        print("🚀 Initiating perfect seek to: \(time)s")
        
        // Set flag to prevent time observer from interfering
        isSeeking = true
        
        // 🎚️ Optimistic position: the thumb stays exactly where the user
        // dropped it while the seek lands (previously it snapped back to the
        // old position until the seek completed — felt broken over network
        // streams).
        currentTime = time
        anchorSmoothTime()
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // 🎚️ 100ms pre-tolerance: an exact-sample (.zero) seek over a network
        // byte-range stream waits for the precise packet; 100ms is inaudible
        // and lets AVPlayer land as soon as nearby audio arrives.
        var completed = false
        player?.seek(to: cmTime, toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600), toleranceAfter: CMTime.zero) { [weak self] finished in
            guard finished else { return }
            completed = true
            
            DispatchQueue.main.async {
                guard let self else { return }
                // Update currentTime immediately after seek completes
                self.currentTime = time
                self.anchorSmoothTime()
                
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
        
        // ⛑️ Safety net: a seek issued against a player that is still
        // resolving (or whose item never becomes ready) can have a completion
        // handler that never fires — that would wedge isSeeking and freeze the
        // time observer (and the seek bar) permanently. Expire the state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self, !completed else { return }
            print("⚠️ Seek completion timed out - resetting seek state")
            self.currentTime = time
            anchorSmoothTime()
            self.setSeekingState(false)
            self.forceUpdateNowPlayingInfo()
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
                    self.setCurrentTrackAndNotify(track)
                    self.playbackState = .buffering
                    self.currentTime = 0
                    anchorSmoothTime()
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
                    self.setCurrentTrackAndNotify(track)
                    self.playbackState = .buffering
                    self.currentTime = 0
                    anchorSmoothTime()
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
    
    // MARK: - Smooth Lyrics Clock
    
    // 🎤 The 1s time observer keeps battery low, but synced lyrics need
    // sub-second resolution. Consumers interpolate: anchor to each observer
    // tick, then extrapolate by wall-clock elapsed * playback speed between
    // ticks. Seek/track changes re-anchor so the estimate never drifts.
    private (set) var smoothAnchorDate = Date()
    
    func anchorSmoothTime() {
        smoothAnchorDate = Date()
    }
    
    /// Best-effort playback position at sub-second resolution.
    func interpolatedTime(now: Date = Date()) -> Double {
        guard playbackState.isPlaying else { return currentTime }
        var elapsed = now.timeIntervalSince(smoothAnchorDate)
        elapsed = min(max(elapsed, 0), 2.0)  // missed ticks must not run away
        var estimate = currentTime + elapsed * playbackSpeed
        if duration > 0 { estimate = min(estimate, duration) }
        return estimate
    }
    
    private func setupPlayerObservers() {
        guard let player = player, let playerItem = playerItem else { return }
        
        // 🔋 BATTERY OPTIMIZATION: Reduce time observer frequency from 0.5s to 1.0s
        // This reduces CPU usage by 50% while maintaining smooth UI updates
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            // Skip updates when paused to avoid wasted work
            guard self.playbackState.isPlaying else { return }
            
            // Skip time updates if we're currently seeking to prevent interference
            guard !self.isSeeking else { return }
            
            self.currentTime = time.seconds
            anchorSmoothTime()
            self.throttledUpdateNowPlayingInfo()
            
            // 🔋 BATTERY EFFICIENCY: Save state less often while active - each
            // save is a JSON encode + UserDefaults flush. State also saves on
            // pause/track change, so 5s only widens the crash-resume window.
            // Save every 5 seconds when app is active, every 10 when inactive.
            let saveInterval = NSApp.isActive ? 5 : 10
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
            .store(in: &playerCancellables)
        
        // Playback end observer
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("🎵 AVPlayerItemDidPlayToEndTime notification received")
                Task {
                    await self?.handlePlaybackEnd()
                }
            }
            .store(in: &playerCancellables)
        
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
            .store(in: &playerCancellables)
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
        
        // 😴 SLEEP TIMER: A sleep-timer fade pauses playback without advancing.
        // If the track runs out while the fade is in progress, ignore the end
        // event — the fade finishes and pauses momentarily.
        guard !isSleepFading else {
            print("😴 Sleep fade in progress - ignoring end-of-track event")
            return
        }
        
        // 😴 SLEEP TIMER: "Pause at end of track" — park here before any
        // radio/next logic. The plain-flag latch makes duplicate end detections
        // for the same item (time observer + AVPlayerItemDidPlayToEndTime can
        // both fire) no-ops until the next playback request.
        guard !isSleepTrackEndHandled else {
            print("😴 Sleep-at-track-end already handled - ignoring duplicate end event")
            return
        }
        if sleepAtTrackEnd {
            isSleepTrackEndHandled = true
            await MainActor.run {
                self.sleepAtTrackEnd = false
                self.pause()
            }
            print("😴 Sleep timer: paused at end of track")
            return
        }
        
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
            // 📻 AUTOPLAY RADIO: Only when the toggle is on. SettingsView binds
            // the same UserDefaults key via @AppStorage, so re-read the live
            // value here. The ended track is captured BEFORE anything advances.
            let radioEnabled = await MainActor.run {
                self.autoplayRadio = UserDefaults.standard.bool(forKey: "autoplayRadioEnabled")
                return self.autoplayRadio
            }
            if radioEnabled, let lastTrack = queueManager.currentTrack ?? currentTrack {
                print("📻 Queue exhausted - autoplay radio extending from: \(lastTrack.title)")
                await extendQueueWithRadioAndContinue(lastTrack: lastTrack)
            } else {
                print("🎵 No more tracks in queue - stopping playback")
                await MainActor.run {
                    self.stop()
                }
            }
        }
    }
    
    // 📻 AUTOPLAY RADIO: Fetch tracks similar to the one that just ended, append
    // the ones not already in the queue, then advance normally so playback
    // continues. Track(from:) keeps each result's own musicSource. If the fetch
    // fails or adds nothing new, stop as usual.
    private func extendQueueWithRadioAndContinue(lastTrack: Track) async {
        do {
            let similar = try await pythonService.getWatchPlaylist(videoId: lastTrack.videoId)
            
            // 📻 Guard against radio loops: skip results already in the queue
            // (or without a usable videoId).
            let queuedIds = Set(queueManager.currentQueue.map { $0.videoId })
            let freshTracks = similar
                .map { Track(from: $0) }
                .filter { !$0.videoId.isEmpty && !queuedIds.contains($0.videoId) }
            
            guard !freshTracks.isEmpty else {
                print("📻 Autoplay radio: no new similar tracks - stopping playback")
                await MainActor.run {
                    self.stop()
                }
                return
            }
            
            await MainActor.run {
                queueManager.addToQueue(freshTracks)
                print("📻 Autoplay radio: added \(freshTracks.count) similar tracks")
            }
            
            // Advance normally so the next track (first radio track at the true
            // end of the queue) starts playing
            await playNext()
        } catch {
            print("⚠️ Autoplay radio fetch failed - stopping playback: \(error)")
            await MainActor.run {
                self.stop()
            }
        }
    }
    
    private func handlePlaybackStalled() {
        isBuffering = true
        
        // ⚡ Re-kick playback immediately: a stalled rate=0 player doesn't pull
        // data as aggressively, so playing right away starts the fetch instead
        // of idling. (The old 2s sleep added that entire duration to every
        // seek past the buffered range.)
        if playbackState.isPlaying {
            player?.play()
            applyPlaybackSpeed()
        }
        
        // Fallback kick + keep supervising: the stream stalled once, it may
        // stall again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.playbackState.isPlaying == true {
                self?.player?.play()
                self?.applyPlaybackSpeed()
            }
            self?.isBuffering = false
            self?.startBufferMonitoring()
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        // 😴 Abort any in-flight sleep fade so it can't pause a freshly-set-up
        // player; the next setup restores volume via player?.volume = volume.
        isSleepFading = false
        
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
        
        playerCancellables.removeAll()
        player = nil
        playerItem = nil
        hlsPlaylistLoader = nil
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
        }
    }
    
    private func restoreLastTrack() {
        if let data = UserDefaults.standard.data(forKey: "lastPlaybackState"),
           let playbackData = try? JSONDecoder().decode(PlaybackData.self, from: data) {
            
            // Restore track
            setCurrentTrackAndNotify(playbackData.track)
            
            // Restore queue state
            if !playbackData.queue.isEmpty {
                queueManager.currentQueue = playbackData.queue
                queueManager.currentIndex = playbackData.currentIndex
                queueManager.shuffleEnabled = playbackData.shuffleEnabled
                queueManager.repeatMode = playbackData.repeatMode
            }
            
            // Restore playback position
            currentTime = playbackData.currentTime
            anchorSmoothTime()
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