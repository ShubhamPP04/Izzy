//
//  PlaybackControlsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @State private var isQueuePresented = false  // Add this state
    
    var body: some View {
        Group {
            if UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") {
                // New minimal style
                VStack(spacing: 8) {
                    // Track Info
                    if let track = playbackManager.currentTrack {
                        TrackInfoView(track: track, playbackManager: playbackManager, isQueuePresented: $isQueuePresented)
                    } else if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorInfoView(errorMessage: errorMessage)
                    }
                    
                    // Error message for playback issues
                    if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorMessageView(errorMessage: errorMessage)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            } else {
                // Original style
                VStack(spacing: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 6 : 8) {
                    // Track Info or Error
                    if let track = playbackManager.currentTrack {
                        TrackInfoView(track: track, playbackManager: playbackManager, isQueuePresented: $isQueuePresented)
                    } else if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorInfoView(errorMessage: errorMessage)
                    }
                    
                    // Error message for playback issues
                    if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorMessageView(errorMessage: errorMessage)
                    } else {
                        // Progress Bar (only show if not in error state)
                        ProgressBarView(playbackManager: playbackManager)
                    }
                    
                    // Control Buttons
                    ControlButtonsView(playbackManager: playbackManager, onQueueButtonTap: {
                        isQueuePresented.toggle()
                    })
                }
                .padding(.horizontal, UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 10 : 16)
                .padding(.vertical, UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 6 : 12)
                .background(
                    RoundedRectangle(cornerRadius: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 6 : 12)
                        .fill(Color.primary.opacity(UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.01 : 0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 6 : 12)
                                .stroke(Color.primary.opacity(UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.02 : 0.05), lineWidth: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.2 : 0.5)
                        )
                )
            }
        }
        // Show queue when button is tapped
        .sheet(isPresented: $isQueuePresented) {
            QueueView(playbackManager: playbackManager, isPresented: $isQueuePresented)
        }
    }
}

// Compact version for use in MusicSearchView
struct CompactPlaybackControlsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @State private var isQueuePresented = false  // Add this state
    
    var body: some View {
        Group {
            if UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") {
                // New minimal style
                VStack(spacing: 8) {
                    // Track Info
                    if let track = playbackManager.currentTrack {
                        TrackInfoView(track: track, playbackManager: playbackManager, isQueuePresented: $isQueuePresented)
                    } else if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorInfoView(errorMessage: errorMessage)
                    }
                    
                    // Error message for playback issues
                    if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorMessageView(errorMessage: errorMessage)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.vertical, 0)
            } else {
                // Original style
                VStack(spacing: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 5 : 8) {
                    // Track Info or Error
                    if let track = playbackManager.currentTrack {
                        TrackInfoView(track: track, playbackManager: playbackManager, isQueuePresented: $isQueuePresented)
                    } else if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorInfoView(errorMessage: errorMessage)
                    }
                    
                    // Error message for playback issues
                    if case .error(let errorMessage) = playbackManager.playbackState {
                        ErrorMessageView(errorMessage: errorMessage)
                    } else {
                        // Progress Bar (only show if not in error state)
                        ProgressBarView(playbackManager: playbackManager)
                    }
                    
                    // Control Buttons
                    ControlButtonsView(playbackManager: playbackManager, onQueueButtonTap: {
                        isQueuePresented.toggle()
                    })
                }
                .padding(.horizontal, UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 8 : 16)
                .padding(.vertical, UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 4 : 12)
                .background(
                    RoundedRectangle(cornerRadius: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 4 : 12)
                        .fill(Color.primary.opacity(UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.005 : 0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 4 : 12)
                                .stroke(Color.primary.opacity(UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.01 : 0.05), lineWidth: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.1 : 0.5)
                        )
                )
            }
        }
        // Show queue when button is tapped
        .sheet(isPresented: $isQueuePresented) {
            QueueView(playbackManager: playbackManager, isPresented: $isQueuePresented)
        }
    }
}

struct ErrorInfoView: View {
    let errorMessage: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Error Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
            
            // Error Info
            VStack(alignment: .leading, spacing: 1) {
                Text("Playback Error")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                
                Text("Unable to play audio")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ErrorMessageView: View {
    let errorMessage: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(errorMessage)
                .font(.system(size: 11))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            if errorMessage.contains("yt-dlp") {
                Text("Install yt-dlp with: pip install yt-dlp")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

struct TrackInfoView: View {
    let track: Track
    @ObservedObject var playbackManager: PlaybackManager
    @State private var isExpanded: Bool
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @Binding var isQueuePresented: Bool  // Add this binding
    
    init(track: Track, playbackManager: PlaybackManager = PlaybackManager.shared, isQueuePresented: Binding<Bool> = .constant(false)) {
        self.track = track
        self.playbackManager = playbackManager
        // Initialize with saved state or false
        self._isExpanded = State(initialValue: UserDefaults.standard.bool(forKey: "albumArtExpanded"))
        self._isQueuePresented = isQueuePresented
    }
    
    var body: some View {
        Group {
            if UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") {
                // New minimal style with expandable album art
                Group {
                    if isExpanded {
                        // Expanded view with slightly larger album art and track info
                        HStack(spacing: 12) {
                            // Slightly larger album artwork
                            AsyncImage(url: URL(string: track.thumbnailURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 20))
                                    }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                    // Save the state
                                    UserDefaults.standard.set(isExpanded, forKey: "albumArtExpanded")
                                }
                            }
                            
                            // Track info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                
                                Text(track.artist)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                // Progress bar
                                VStack(spacing: 4) {
                                    Slider(
                                        value: isDragging ? $dragValue : .constant(playbackManager.progress),
                                        in: 0...1,
                                        onEditingChanged: { editing in
                                            if editing {
                                                // Started dragging - initialize dragValue with current progress
                                                isDragging = true
                                                dragValue = playbackManager.progress
                                            } else {
                                                // Finished dragging - seek to the new position
                                                isDragging = false
                                                let newTime = dragValue * playbackManager.duration
                                                playbackManager.seek(to: newTime)
                                            }
                                        }
                                    )
                                    .accentColor(.blue)
                                    .frame(height: 16)
                                    .scaleEffect(y: 1.0, anchor: .center)
                                    
                                    // Time info
                                    HStack(spacing: 4) {
                                        Text(playbackManager.currentTime.formattedDuration)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                        
                                        Text("/")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        
                                        Text(playbackManager.duration.formattedDuration)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                                
                                // Control buttons with queue button
                                HStack(spacing: 16) {
                                    // Shuffle/Repeat button
                                    Button(action: {
                                        // 🔋 BATTERY EFFICIENCY: Save state when shuffle/repeat mode changes
                                        playbackManager.savePlaybackState()
                                        toggleShuffleRepeatMode()
                                    }) {
                                        Image(systemName: shuffleRepeatModeImage())
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(shuffleRepeatModeColor())
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Previous button
                                    Button(action: {
                                        // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                                        playbackManager.savePlaybackState()
                                        Task {
                                            await playbackManager.playPrevious()
                                        }
                                    }) {
                                        Image(systemName: "backward.fill")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(playbackManager.queue.hasPrevious ? .primary : .secondary)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(!playbackManager.queue.hasPrevious)
                                    
                                    // Play/Pause button
                                    Button(action: {
                                        // 🔋 BATTERY EFFICIENCY: Save state when play/pause is pressed
                                        playbackManager.savePlaybackState()
                                        if playbackManager.isPlaying {
                                            playbackManager.pause()
                                        } else {
                                            // Check if we need to resume from a saved position
                                            if playbackManager.playbackState == .stopped && playbackManager.currentTime > 0 {
                                                Task {
                                                    await playbackManager.resumeFromSavedPosition()
                                                }
                                            } else {
                                                playbackManager.resume()
                                            }
                                        }
                                    }) {
                                        Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .frame(width: 30, height: 30)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                            .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Next button
                                    Button(action: {
                                        // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                                        playbackManager.savePlaybackState()
                                        Task {
                                            await playbackManager.playNext()
                                        }
                                    }) {
                                        Image(systemName: "forward.fill")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(playbackManager.queue.hasNext ? .primary : .secondary)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(!playbackManager.queue.hasNext)
                                    
                                    // Queue button
                                    Button(action: {
                                        isQueuePresented.toggle()
                                    }) {
                                        Image(systemName: "list.bullet")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.primary)
                                            .frame(width: 20, height: 20)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                                )
                        )
                    } else {
                        // Compact minimal view
                        HStack(spacing: 12) {
                            // Album artwork with tap to expand
                            AsyncImage(url: URL(string: track.thumbnailURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                    // Save the state
                                    UserDefaults.standard.set(isExpanded, forKey: "albumArtExpanded")
                                }
                            }
                            
                            // Track info with vertical layout
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(track.artist)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Progress indicator as a seekable slider
                            VStack(spacing: 4) {
                                Slider(
                                    value: isDragging ? $dragValue : .constant(playbackManager.progress),
                                    in: 0...1,
                                    onEditingChanged: { editing in
                                        if editing {
                                            // Started dragging - initialize dragValue with current progress
                                            isDragging = true
                                            dragValue = playbackManager.progress
                                        } else {
                                            // Finished dragging - seek to the new position
                                            isDragging = false
                                            let newTime = dragValue * playbackManager.duration
                                            playbackManager.seek(to: newTime)
                                        }
                                    }
                                )
                                .accentColor(.blue)
                                .frame(width: 80)
                                .scaleEffect(y: 0.8, anchor: .center)
                                
                                // Time info in small format
                                HStack(spacing: 4) {
                                    Text(playbackManager.currentTime.formattedDuration)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                    
                                    Text("/")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    
                                    Text(playbackManager.duration.formattedDuration)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            
                            // Control buttons (Previous, Play/Pause, Next) with Queue button
                            HStack(spacing: 8) {
                                // Shuffle/Repeat button
                                Button(action: {
                                    // 🔋 BATTERY EFFICIENCY: Save state when shuffle/repeat mode changes
                                    playbackManager.savePlaybackState()
                                    toggleShuffleRepeatMode()
                                }) {
                                    Image(systemName: shuffleRepeatModeImage())
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(shuffleRepeatModeColor())
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Previous button
                                Button(action: {
                                    // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                                    playbackManager.savePlaybackState()
                                    Task {
                                        await playbackManager.playPrevious()
                                    }
                                }) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(playbackManager.queue.hasPrevious ? .primary : .secondary)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!playbackManager.queue.hasPrevious)
                                
                                // Play/Pause button
                                Button(action: {
                                    // 🔋 BATTERY EFFICIENCY: Save state when play/pause is pressed
                                    playbackManager.savePlaybackState()
                                    if playbackManager.isPlaying {
                                        playbackManager.pause()
                                    } else {
                                        // Check if we need to resume from a saved position
                                        if playbackManager.playbackState == .stopped && playbackManager.currentTime > 0 {
                                            Task {
                                                await playbackManager.resumeFromSavedPosition()
                                            }
                                        } else {
                                            playbackManager.resume()
                                        }
                                    }
                                }) {
                                    Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                        .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Next button
                                Button(action: {
                                    // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                                    playbackManager.savePlaybackState()
                                    Task {
                                        await playbackManager.playNext()
                                    }
                                }) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(playbackManager.queue.hasNext ? .primary : .secondary)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(!playbackManager.queue.hasNext)
                                
                                // Queue button
                                Button(action: {
                                    isQueuePresented.toggle()
                                }) {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary.opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                                )
                        )
                    }
                }
            } else {
                // Original style
                HStack(spacing: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 8 : 12) {
                    // Bigger album artwork with slightly rounded corners
                    AsyncImage(url: URL(string: track.thumbnailURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 6 : 8)
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 16 : 20))
                            }
                    }
                    .frame(width: isExpanded ? 200 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 40 : 60), height: isExpanded ? 200 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 40 : 60))
                    .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 16 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 4 : 8)))
                    .shadow(color: .black.opacity(isExpanded ? 0.3 : 0.1), radius: isExpanded ? 12 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 1 : 4), x: 0, y: isExpanded ? 6 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.5 : 2))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                            // Save the state
                            UserDefaults.standard.set(isExpanded, forKey: "albumArtExpanded")
                        }
                    }
                    .zIndex(isExpanded ? 1 : 0)
                    
                    // Track info (now shown even when expanded, but with different styling when expanded)
                    VStack(alignment: .leading, spacing: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 1 : 4) {
                        Text(track.title)
                            .font(.system(size: isExpanded ? 16 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 11 : 14), weight: isExpanded ? .bold : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? .medium : .semibold)))
                            .foregroundColor(.primary)
                            .lineLimit(isExpanded ? 3 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 1 : 2))
                            .multilineTextAlignment(.leading)
                        
                        Text(track.artist)
                            .font(.system(size: isExpanded ? 14 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 9 : 12), weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Show resume info if track is stopped but has saved position
                        if playbackManager.playbackState == .stopped && playbackManager.currentTime > 0 {
                            Text("Resume from \(playbackManager.currentTime.formattedDuration)")
                                .font(.system(size: isExpanded ? 12 : (UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 7 : 10), weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .opacity(isExpanded ? 0.9 : 1.0)
                    
                    Spacer()
                    
                    // Resume button if track is stopped but has saved position (only shown when not expanded)
                    if !isExpanded && playbackManager.playbackState == .stopped && playbackManager.currentTime > 0 {
                        Button(action: {
                            Task {
                                await playbackManager.resumeFromSavedPosition()
                            }
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 18 : 24))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .onTapGesture(count: 2) {
                    // Double tap to toggle expansion
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                        // Save the state
                        UserDefaults.standard.set(isExpanded, forKey: "albumArtExpanded")
                    }
                }
            }
        }
    }
    
    // Toggle shuffle mode
    private func toggleShuffleMode() {
        playbackManager.queue.toggleShuffle()
    }
    
    // Toggle through shuffle/repeat modes as requested by user:
    // Off -> On (auto-play next) -> Repeat (repeat current song) -> Off
    private func toggleShuffleRepeatMode() {
        switch playbackManager.queue.repeatMode {
        case .none:
            // Off -> On (auto-play next)
            playbackManager.queue.repeatMode = .all
            playbackManager.queue.shuffleEnabled = false
        case .all:
            // On -> Repeat (repeat current song)
            playbackManager.queue.repeatMode = .single
            playbackManager.queue.shuffleEnabled = false
        case .single:
            // Repeat -> Off
            playbackManager.queue.repeatMode = .none
            playbackManager.queue.shuffleEnabled = false
        }
    }
    
    // Return appropriate image based on current mode
    private func shuffleRepeatModeImage() -> String {
        switch playbackManager.queue.repeatMode {
        case .none:
            return "repeat"
        case .all:
            return "repeat"
        case .single:
            return "repeat.1"
        }
    }
    
    // Return appropriate color based on current mode
    private func shuffleRepeatModeColor() -> Color {
        switch playbackManager.queue.repeatMode {
        case .none:
            return .secondary
        case .all, .single:
            return .blue
        }
    }
}

struct ProgressBarView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        Group {
            if UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") {
                // Hidden in minimal mode since progress is shown in TrackInfoView
                EmptyView()
            } else {
                // Original style
                HStack(spacing: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 4 : 8) {
                    // Current time
                    Text(playbackManager.currentTime.formattedDuration)
                        .font(.system(size: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 5 : 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .opacity(UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.7 : 1.0)
                    
                    // Minimal progress slider
                    Slider(
                        value: isDragging ? $dragValue : .constant(playbackManager.progress),
                        in: 0...1,
                        onEditingChanged: { editing in
                            if editing {
                                // Started dragging - initialize dragValue with current progress
                                isDragging = true
                                dragValue = playbackManager.progress
                            } else {
                                // Finished dragging - seek to the new position
                                isDragging = false
                                let newTime = dragValue * playbackManager.duration
                                playbackManager.seek(to: newTime)
                            }
                        }
                    )
                    .accentColor(.blue)
                    .frame(height: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 12 : nil)
                    
                    // Duration
                    Text(playbackManager.duration.formattedDuration)
                        .font(.system(size: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 5 : 8, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .opacity(UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 0.7 : 1.0)
                }
            }
        }
    }
}

struct ControlButtonsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    var onQueueButtonTap: (() -> Void)? = nil  // Add this callback parameter
    
    var body: some View {
        Group {
            if UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") {
                // Hidden in minimal mode since controls are integrated in TrackInfoView
                EmptyView()
            } else {
                // Original style
                HStack(spacing: UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 8 : 20) {
                    // Check if playback buttons should be centered
                    let centerButtons = UserDefaults.standard.bool(forKey: "centerPlaybackButtons")
                    let minimalMode = UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer")
                    
                    if centerButtons {
                        // Centered layout with shuffle button on the left
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state when shuffle/repeat mode changes
                            playbackManager.savePlaybackState()
                            toggleShuffleRepeatMode()
                        }) {
                            Image(systemName: shuffleRepeatModeImage())
                                .font(.system(size: minimalMode ? 10 : 14, weight: .medium))
                                .foregroundColor(shuffleRepeatModeColor())
                        }
                        .buttonStyle(ControlButtonStyle())
                        
                        Spacer()
                        
                        // Previous button
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                            playbackManager.savePlaybackState()
                            Task {
                                await playbackManager.playPrevious()
                            }
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: minimalMode ? 12 : 16, weight: .medium))
                                .foregroundColor(playbackManager.queue.hasPrevious ? .primary : .secondary)
                        }
                        .buttonStyle(ControlButtonStyle())
                        .disabled(!playbackManager.queue.hasPrevious)
                        
                        // Play/Pause button (bigger)
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state when play/pause is pressed
                            playbackManager.savePlaybackState()
                            if playbackManager.isPlaying {
                                playbackManager.pause()
                            } else {
                                playbackManager.resume()
                            }
                        }) {
                            Group {
                                if playbackManager.isBuffering {
                                    ProgressView()
                                        .scaleEffect(minimalMode ? 0.5 : 0.8)
                                } else {
                                    Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: minimalMode ? 12 : 16, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: minimalMode ? 28 : 40, height: minimalMode ? 28 : 40)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(minimalMode ? 0.2 : 0.3), radius: minimalMode ? 1 : 4, x: 0, y: minimalMode ? 0.5 : 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Next button
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                            playbackManager.savePlaybackState()
                            Task {
                                await playbackManager.playNext()
                            }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: minimalMode ? 12 : 16, weight: .medium))
                                .foregroundColor(playbackManager.queue.hasNext ? .primary : .secondary)
                        }
                        .buttonStyle(ControlButtonStyle())
                        .disabled(!playbackManager.queue.hasNext)
                        
                        Spacer()
                        
                        // Queue button
                        if let onQueueButtonTap = onQueueButtonTap {
                            Button(action: onQueueButtonTap) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: minimalMode ? 10 : 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(ControlButtonStyle())
                        }
                    } else {
                        // Left-aligned layout (default) with shuffle button on the left
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state when shuffle/repeat mode changes
                            playbackManager.savePlaybackState()
                            toggleShuffleRepeatMode()
                        }) {
                            Image(systemName: shuffleRepeatModeImage())
                                .font(.system(size: minimalMode ? 10 : 14, weight: .medium))
                                .foregroundColor(shuffleRepeatModeColor())
                        }
                        .buttonStyle(ControlButtonStyle())
                        
                        // Previous button
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                            playbackManager.savePlaybackState()
                            Task {
                                await playbackManager.playPrevious()
                            }
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: minimalMode ? 12 : 16, weight: .medium))
                                .foregroundColor(playbackManager.queue.hasPrevious ? .primary : .secondary)
                        }
                        .buttonStyle(ControlButtonStyle())
                        .disabled(!playbackManager.queue.hasPrevious)
                        
                        // Play/Pause button (bigger)
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state when play/pause is pressed
                            playbackManager.savePlaybackState()
                            if playbackManager.isPlaying {
                                playbackManager.pause()
                            } else {
                                playbackManager.resume()
                            }
                        }) {
                            Group {
                                if playbackManager.isBuffering {
                                    ProgressView()
                                        .scaleEffect(minimalMode ? 0.5 : 0.8)
                                } else {
                                    Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: minimalMode ? 12 : 16, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(width: minimalMode ? 28 : 40, height: minimalMode ? 28 : 40)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(minimalMode ? 0.2 : 0.3), radius: minimalMode ? 1 : 4, x: 0, y: minimalMode ? 0.5 : 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Next button
                        Button(action: {
                            // 🔋 BATTERY EFFICIENCY: Save state before skipping tracks
                            playbackManager.savePlaybackState()
                            Task {
                                await playbackManager.playNext()
                            }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: minimalMode ? 12 : 16, weight: .medium))
                                .foregroundColor(playbackManager.queue.hasNext ? .primary : .secondary)
                        }
                        .buttonStyle(ControlButtonStyle())
                        .disabled(!playbackManager.queue.hasNext)
                        
                        // Queue button
                        if let onQueueButtonTap = onQueueButtonTap {
                            Button(action: onQueueButtonTap) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: minimalMode ? 10 : 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(ControlButtonStyle())
                        }
                        
                        // Up Next button
                        Button(action: {
                            // Up Next functionality temporarily disabled due to state mutation issues
                            // TODO: Implement proper state management for tab switching
                        }) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: minimalMode ? 10 : 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(ControlButtonStyle())
                        
                        Spacer()
                    }
                }
                .padding(.vertical, UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") ? 2 : 0)
            }
        }
    }
    
    // Toggle through shuffle/repeat modes as requested by user:
    // Off -> On (auto-play next) -> Repeat (repeat current song) -> Off
    private func toggleShuffleRepeatMode() {
        switch playbackManager.queue.repeatMode {
        case .none:
            // Off -> On (auto-play next)
            playbackManager.queue.repeatMode = .all
            playbackManager.queue.shuffleEnabled = false
        case .all:
            // On -> Repeat (repeat current song)
            playbackManager.queue.repeatMode = .single
            playbackManager.queue.shuffleEnabled = false
        case .single:
            // Repeat -> Off
            playbackManager.queue.repeatMode = .none
            playbackManager.queue.shuffleEnabled = false
        }
    }
    
    // Return appropriate image based on current mode
    private func shuffleRepeatModeImage() -> String {
        switch playbackManager.queue.repeatMode {
        case .none:
            return "repeat"
        case .all:
            return "repeat"
        case .single:
            return "repeat.1"
        }
    }
    
    // Return appropriate color based on current mode
    private func shuffleRepeatModeColor() -> Color {
        switch playbackManager.queue.repeatMode {
        case .none:
            return .secondary
        case .all, .single:
            return .blue
        }
    }
}

struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}



// MARK: - Playback State Display

struct PlaybackStateView: View {
    @ObservedObject var playbackManager: PlaybackManager
    
    var body: some View {
        HStack(spacing: 6) {
            switch playbackManager.playbackState {
            case .playing:
                Image(systemName: "play.fill")
                    .foregroundColor(.green)
                Text("Playing")
                    .foregroundColor(.green)
                
            case .paused:
                Image(systemName: "pause.fill")
                    .foregroundColor(.orange)
                Text("Paused")
                    .foregroundColor(.orange)
                
            case .buffering:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Buffering...")
                    .foregroundColor(.secondary)
                
            case .stopped:
                Image(systemName: "stop.fill")
                    .foregroundColor(.secondary)
                Text("Stopped")
                    .foregroundColor(.secondary)
                
            case .error(_):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error")
                    .foregroundColor(.red)
            }
            
            // Add a test button for debugging remote commands
            #if DEBUG
            Button(action: {
                playbackManager.testRemoteCommands()
            }) {
                Image(systemName: "hammer")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Test Remote Commands")
            #endif
        }
        .font(.system(size: 10, weight: .medium))
    }
}

// MARK: - Queue Info View

struct QueueInfoView: View {
    @ObservedObject var queueManager: QueueManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "music.note.list")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text("\(queueManager.currentIndex + 1) of \(queueManager.queueSize)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PlaybackControlsView(
        playbackManager: {
            let manager = PlaybackManager.shared
            manager.currentTrack = Track(
                title: "Sample Song",
                artist: "Sample Artist",
                duration: 180,
                videoId: "sample"
            )
            return manager
        }()
    )
    .frame(width: 400)
    .padding()
    .background(Color.black.opacity(0.1))
}