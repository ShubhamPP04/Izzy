//
//  MenuBarView.swift
//  Izzy
//
//  Created by GitHub Copilot on 11/09/25.
//

import SwiftUI

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
                        Task {
                            if searchState.playbackManager.playbackState == .playing {
                                await searchState.playbackManager.pause()
                            } else {
                                await searchState.playbackManager.resume()
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
        // Enhanced glassy appearance with vibrancy effect
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.3)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .cornerRadius(12)
    }
}