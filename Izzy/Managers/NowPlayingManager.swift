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
        print("🎮 Updating Now Playing info: \(track.title) - Playing: \(isPlaying)")
        
        #if os(macOS)
        // FIXED: Remove aggressive app activation that interferes with other apps
        // The app should only receive remote commands, not force itself to become active
        // This allows users to work in other apps while music plays in the background
        #endif
        
        // Ensure remote commands are enabled when we start playing
        enableRemoteCommands()
        
        // CRITICAL FIX: On macOS, you MUST explicitly set the playbackState
        // Unlike iOS, macOS cannot infer the playback state from AVAudioSession
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        print("🎮 CRITICAL: Set playbackState to \(isPlaying ? "playing" : "paused")")
        #endif
        
        var nowPlayingInfo: [String: Any] = [:]
        
        // Basic track info
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        
        if let album = track.album {
            nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
        }
        
        // Playback info
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        print("🎮 Now Playing info set - Rate: \(isPlaying ? 1.0 : 0.0), Time: \(currentTime)/\(duration)")
        
        // Load artwork if available
        if let thumbnailURL = track.thumbnailURL {
            loadArtwork(from: thumbnailURL) { artwork in
                if let artwork = artwork {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    print("🎮 Added artwork to Now Playing info")
                }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                print("🎮 Now Playing info updated with artwork")
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            print("🎮 Now Playing info updated without artwork")
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
        // Reset playback state when clearing
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        print("🎮 CRITICAL: Set playbackState to stopped")
        #endif
        
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
        
        // Remove any existing targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
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
        
        print("🎮 Remote command center setup complete - all commands enabled")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let remotePlayCommand = Notification.Name("remotePlayCommand")
    static let remotePauseCommand = Notification.Name("remotePauseCommand")
    static let remoteNextCommand = Notification.Name("remoteNextCommand")
    static let remotePreviousCommand = Notification.Name("remotePreviousCommand")
    static let remoteSeekCommand = Notification.Name("remoteSeekCommand")
}