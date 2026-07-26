//
//  NowPlayingManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation
import MediaPlayer
import AppKit
import AVFoundation

class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()
    
    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        #if os(macOS)
        // 🔋 BATTERY OPTIMIZATION: Use background queue for workspace notifications
        // to avoid blocking the main thread
        DispatchQueue.global(qos: .background).async {
            let workspace = NSWorkspace.shared
            workspace.notificationCenter.addObserver(
                self,
                selector: #selector(self.handleWorkspaceActivation(_:)),
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
        }
        #endif
        
        print("🎮 Audio session setup complete")
    }
    
    @objc private func handleWorkspaceActivation(_ notification: Notification) {
        // Ensure our app becomes the active media app when activated
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("🎮 Izzy became active - ensuring remote commands are enabled")
            enableRemoteCommands()
        }
    }
    
    // MARK: - Now Playing Info
    
    func updateNowPlayingInfo(track: Track, isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) {
        let center = MPNowPlayingInfoCenter.default()

        #if os(macOS)
        // macOS cannot infer playback state from an audio session; it must be explicit.
        center.playbackState = isPlaying ? .playing : .paused
        #endif

        // Fast path: same track, clock advanced. Every one-second tick used to
        // rebuild the entire dictionary and re-resolve artwork, churning the system
        // Now Playing session ~60x a minute for the two values that actually moved.
        if track.videoId == nowPlayingTrackId {
            var info = center.nowPlayingInfo ?? nowPlayingBaseInfo
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            info[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingBaseInfo = info
            center.nowPlayingInfo = info
            return
        }

        // New track: publish full metadata and re-assert the transport commands.
        nowPlayingTrackId = track.videoId
        enableRemoteCommands()

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let album = track.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        nowPlayingBaseInfo = info
        center.nowPlayingInfo = info
        print("🎮 Now Playing: \(track.title) — playing: \(isPlaying)")

        guard let thumbnailURL = track.thumbnailURL else { return }
        let requestedId = track.videoId
        loadArtwork(from: thumbnailURL) { [weak self] artwork in
            // Drop stale completions: artwork for a previous track could otherwise
            // land after the user had already skipped past it.
            guard let self, let artwork, self.nowPlayingTrackId == requestedId else { return }
            var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? self.nowPlayingBaseInfo
            updated[MPMediaItemPropertyArtwork] = artwork
            self.nowPlayingBaseInfo = updated
            MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
        }
    }
    
    private func enableRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Re-enable commands to ensure they're active
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        print("🎮 Remote commands re-enabled")
    }
    
    func clearNowPlayingInfo() {
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        #endif

        nowPlayingTrackId = nil
        nowPlayingBaseInfo = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        print("🎮 Now Playing info cleared")
    }
    
    // Test method to verify remote commands are working
    func testRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        print("🎮 Testing remote commands:")
        print("🎮 Play command enabled: \(commandCenter.playCommand.isEnabled)")
        print("🎮 Pause command enabled: \(commandCenter.pauseCommand.isEnabled)")
        print("🎮 Next command enabled: \(commandCenter.nextTrackCommand.isEnabled)")
        print("🎮 Previous command enabled: \(commandCenter.previousTrackCommand.isEnabled)")
        print("🎮 Seek command enabled: \(commandCenter.changePlaybackPositionCommand.isEnabled)")
        
        // Test if we have Now Playing info
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            print("🎮 Current Now Playing info: \(nowPlayingInfo)")
        } else {
            print("🎮 No Now Playing info set")
        }
        
        // Print current playback state
        print("🎮 Current playback state: \(MPNowPlayingInfoCenter.default().playbackState.rawValue)")
        
        // Check if app is active
        #if os(macOS)
        print("🎮 App is active: \(NSApp.isActive)")
        print("🎮 Main window: \(NSApp.mainWindow != nil)")
        print("🎮 Key window: \(NSApp.keyWindow != nil)")
        #endif
    }
    
    // MARK: - Artwork Loading
    
    // 🔋 BATTERY OPTIMIZATION: Artwork loading cache and background processing
    private var artworkCache = NSCache<NSString, MPMediaItemArtwork>()

    // Identifies the item currently published, so a progress tick can patch two
    // keys instead of republishing the whole Now Playing dictionary.
    private var nowPlayingTrackId: String?
    private var nowPlayingBaseInfo: [String: Any] = [:]
    
    private func loadArtwork(from urlString: String, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let cacheKey = NSString(string: urlString)
        
        // 🔋 Check cache first to avoid unnecessary network requests
        if let cachedArtwork = artworkCache.object(forKey: cacheKey) {
            completion(cachedArtwork)
            return
        }
        
        // 🔋 Load artwork on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .utility).async {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let data = data,
                      error == nil,
                      let image = NSImage(data: data) else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                    return
                }
                
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    return image
                }
                
                // 🔋 Cache the artwork for future use
                self?.artworkCache.setObject(artwork, forKey: cacheKey)
                
                DispatchQueue.main.async {
                    completion(artwork)
                }
            }.resume()
        }
    }
    
    // MARK: - Remote Command Center
    
    private func setupRemoteCommandCenter() {
        print("🎮 Setting up Remote Command Center...")
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Disable all commands first to reset state
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        
        // Remove any existing targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        #if os(macOS)
        // For macOS, enable remote commands without forcing app activation
        // This allows media controls to work while letting users focus on other apps
        #endif
        
        // Play command
        commandCenter.playCommand.addTarget { _ in
            print("🎮 Remote play command received")
            NotificationCenter.default.post(name: .remotePlayCommand, object: nil)
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { _ in
            print("🎮 Remote pause command received")
            NotificationCenter.default.post(name: .remotePauseCommand, object: nil)
            return .success
        }

        // Toggle play/pause. This is what the macOS Control Center transport button
        // and most keyboard/headset play keys actually send — without it the native
        // Now Playing widget rendered correctly but its button did nothing.
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            print("🎮 Remote toggle play/pause command received")
            NotificationCenter.default.post(name: .remoteTogglePlayPauseCommand, object: nil)
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.addTarget { _ in
            print("🎮 Remote next command received")
            NotificationCenter.default.post(name: .remoteNextCommand, object: nil)
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.addTarget { _ in
            print("🎮 Remote previous command received")
            NotificationCenter.default.post(name: .remotePreviousCommand, object: nil)
            return .success
        }
        
        // Seek command
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                print("🎮 Remote seek command received: \(event.positionTime)")
                NotificationCenter.default.post(
                    name: .remoteSeekCommand,
                    object: nil,
                    userInfo: ["position": event.positionTime]
                )
                return .success
            }
            return .commandFailed
        }
        
        // Enable the commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        print("🎮 Remote command center setup complete - all commands enabled")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let remotePlayCommand = Notification.Name("remotePlayCommand")
    static let remotePauseCommand = Notification.Name("remotePauseCommand")
    static let remoteTogglePlayPauseCommand = Notification.Name("remoteTogglePlayPauseCommand")
    static let remoteNextCommand = Notification.Name("remoteNextCommand")
    static let remotePreviousCommand = Notification.Name("remotePreviousCommand")
    static let remoteSeekCommand = Notification.Name("remoteSeekCommand")
}