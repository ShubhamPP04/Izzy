//
//  PlaybackControlsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Track Info or Error
            if let track = playbackManager.currentTrack {
                TrackInfoView(track: track, playbackManager: playbackManager)
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
            ControlButtonsView(playbackManager: playbackManager)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
}

// Compact version for use in MusicSearchView
struct CompactPlaybackControlsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    
    var body: some View {
        VStack(spacing: 8) {
            // Track Info or Error
            if let track = playbackManager.currentTrack {
                TrackInfoView(track: track, playbackManager: playbackManager)
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
            ControlButtonsView(playbackManager: playbackManager)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        )
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
    
    init(track: Track, playbackManager: PlaybackManager = PlaybackManager.shared) {
        self.track = track
        self.playbackManager = playbackManager
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Bigger album artwork with slightly rounded corners
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
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(track.artist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Show resume info if track is stopped but has saved position
                if playbackManager.playbackState == .stopped && playbackManager.currentTime > 0 {
                    Text("Resume from \(playbackManager.currentTime.formattedDuration)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Resume button if track is stopped but has saved position
            if playbackManager.playbackState == .stopped && playbackManager.currentTime > 0 {
                Button(action: {
                    Task {
                        await playbackManager.resumeFromSavedPosition()
                    }
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ProgressBarView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Current time
            Text(playbackManager.currentTime.formattedDuration)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
            
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
            
            // Duration
            Text(playbackManager.duration.formattedDuration)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

struct ControlButtonsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Previous button
            Button(action: {
                Task {
                    await playbackManager.playPrevious()
                }
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(playbackManager.queue.hasPrevious ? .primary : .secondary)
            }
            .buttonStyle(ControlButtonStyle())
            .disabled(!playbackManager.queue.hasPrevious)
            
            // Play/Pause button (bigger)
            Button(action: {
                if playbackManager.isPlaying {
                    playbackManager.pause()
                } else {
                    playbackManager.resume()
                }
            }) {
                Group {
                    if playbackManager.isBuffering {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Next button
            Button(action: {
                Task {
                    await playbackManager.playNext()
                }
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(playbackManager.queue.hasNext ? .primary : .secondary)
            }
            .buttonStyle(ControlButtonStyle())
            .disabled(!playbackManager.queue.hasNext)
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