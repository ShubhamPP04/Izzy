//
//  MenuBarView.swift
//  Izzy
//
//  Created by GitHub Copilot on 11/09/25.
//

import SwiftUI

// MARK: - Hover Volume Slider Component
struct HoverVolumeSlider: View {
    @ObservedObject var playbackManager: PlaybackManager
    @State private var isHovering = false
    @State private var hideTask: Task<Void, Never>?
    let iconSize: CGFloat
    let iconColor: Color

    init(playbackManager: PlaybackManager, iconSize: CGFloat = 14, iconColor: Color = .primary) {
        self.playbackManager = playbackManager
        self.iconSize = iconSize
        self.iconColor = iconColor
    }

    var volumeIcon: String {
        if playbackManager.volume == 0 {
            return "speaker.slash.fill"
        } else if playbackManager.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if playbackManager.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // Volume icon button
            Button(action: {
                // Toggle mute
                if playbackManager.volume > 0 {
                    playbackManager.volume = 0
                } else {
                    playbackManager.volume = 0.7
                }
            }) {
                Image(systemName: volumeIcon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Volume: \(Int(playbackManager.volume * 100))%")

            // Volume slider (shown on hover)
            if isHovering {
                HStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { Double(playbackManager.volume) },
                            set: { playbackManager.volume = Float($0) }
                        ),
                        in: 0...1
                    )
                    .frame(width: 90)

                    Text("\(Int(playbackManager.volume * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .leading).combined(with: .opacity),
                    removal: .scale(scale: 0.9, anchor: .leading).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            hideTask?.cancel()

            if hovering {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isHovering = true
                }
            } else {
                // Delay hiding to prevent flicker
                hideTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    if !Task.isCancelled {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isHovering = false
                        }
                    }
                }
            }
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentTrack = searchState.playbackManager.currentTrack {
                // Currently playing content
                HStack(spacing: 12) {
                    // Album artwork
                    AsyncImage(url: URL(string: currentTrack.thumbnailURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            )
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    
                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentTrack.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text(currentTrack.artist)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        // Progress bar
                        ProgressView(value: searchState.playbackManager.currentTime, 
                                   total: searchState.playbackManager.duration)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(x: 1, y: 0.5)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Control buttons
                HStack(spacing: 16) {
                    // Previous button
                    Button(action: {
                        Task {
                            await searchState.playbackManager.playPrevious()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(searchState.playbackManager.queue.hasPrevious ? .primary : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!searchState.playbackManager.queue.hasPrevious)
                    
                    // Play/Pause button
                    Button(action: {
                        if searchState.playbackManager.playbackState == .playing {
                            searchState.playbackManager.pause()
                        } else {
                            // Check if we need to resume from a saved position
                            if searchState.playbackManager.playbackState == .stopped && searchState.playbackManager.currentTime > 0 {
                                Task {
                                    await searchState.playbackManager.resumeFromSavedPosition()
                                }
                            } else if searchState.playbackManager.currentTrack != nil {
                                searchState.playbackManager.resume()
                            } else {
                                print("No track to play")
                            }
                        }
                    }) {
                        Image(systemName: searchState.playbackManager.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Next button
                    Button(action: {
                        Task {
                            await searchState.playbackManager.playNext()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(searchState.playbackManager.queue.hasNext ? .primary : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!searchState.playbackManager.queue.hasNext)

                    Spacer()

                    // Volume slider with hover
                    HoverVolumeSlider(playbackManager: searchState.playbackManager)

                    // Open main app button
                    Button(action: {
                        // Open the main Izzy window
                        windowManager.showWindow()
                        onClose()
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
            } else {
                // Not playing state
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    
                    Text("No music playing")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button("Open Izzy") {
                        // Open the main Izzy window
                        windowManager.showWindow()
                        onClose()
                    }
                    .font(.system(size: 11))
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        // Native Liquid Glass on macOS 26+, material fallback on older systems
        .modifier(MenuBarGlassModifier())
        .cornerRadius(12)
    }
}

// MARK: - Menu Bar Glass Background

struct MenuBarGlassModifier: ViewModifier {
    @ObservedObject private var settings = LiquidGlassSettings.shared

    func body(content: Content) -> some View {
        if settings.isEnabled {
            if #available(macOS 26.0, *) {
                content
                    .background {
                        GlassEffectContainer(spacing: 0) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.clear)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        }
                    }
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.clear)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.1), .white.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1), .white.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
        }
    }
}