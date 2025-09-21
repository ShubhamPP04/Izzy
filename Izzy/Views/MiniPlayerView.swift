//
//  MiniPlayerView.swift
//  Izzy
//
//  Created by Assistant on 21/09/25.
//

import SwiftUI
import AppKit

// MARK: - Mini Player View
struct MiniPlayerView: View {
    @ObservedObject var manager: MiniPlayerManager
    let searchState: SearchState
    @State private var isDragging: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            AsyncImage(url: URL(string: manager.currentTrack?.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            .font(.title3)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Track info and controls
            VStack(alignment: .leading, spacing: 4) {
                // Track title and artist
                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.currentTrack?.title ?? "No track playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(manager.currentTrack?.artist ?? "")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                // Controls row
                HStack(spacing: 12) {
                    // Previous button
                    Button(action: { 
                        Task {
                            await searchState.playbackManager.playPrevious()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!searchState.playbackManager.queue.hasPrevious)
                    
                    // Play/Pause button
                    Button(action: { 
                        if manager.playbackState.isPlaying {
                            searchState.playbackManager.pause()
                        } else {
                            // Check if we need to resume from a saved position
                            if manager.playbackState == .stopped && manager.currentTime > 0 {
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
                        Image(systemName: manager.playbackState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Next button
                    Button(action: { 
                        Task {
                            await searchState.playbackManager.playNext()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!searchState.playbackManager.queue.hasNext)
                    
                    Spacer()
                }
                
                // Progress bar with time labels
                VStack(spacing: 2) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 3)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: progressWidth(geometry.size.width), height: 3)
                                .animation(.linear(duration: 0.1), value: manager.currentTime)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            seekToPosition(location.x / geometry.size.width)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    seekToPosition(progress)
                                }
                        )
                    }
                    .frame(height: 3)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(manager.currentTime))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(formatTime(manager.duration))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(12)
        .background(
            LiquidGlassMiniPlayerBackground()
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            print("🎵 Mini Player View appeared")
        }
    }
    
    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard manager.duration > 0 else { return 0 }
        return totalWidth * CGFloat(manager.currentTime / manager.duration)
    }
    
    private func seekToPosition(_ position: Double) {
        let newTime = position * manager.duration
        searchState.playbackManager.seek(to: newTime)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Liquid Glass Mini Player Background
struct LiquidGlassMiniPlayerBackground: View {
    @ObservedObject private var settings = LiquidGlassSettings.shared
    
    var body: some View {
        if settings.isEnabled {
            ZStack {
                // Base liquid glass background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                
                // Enhanced glass layers for depth
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.08),
                                .clear,
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .preferredColorScheme(.dark)
        } else {
            // Standard background when liquid glass is disabled
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        }
    }
}