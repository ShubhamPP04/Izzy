//
//  UpNextView.swift
//  Izzy
//
//  Created by Shubham Kumar on 13/09/25.
//

import SwiftUI

struct UpNextView: View {
    @ObservedObject var searchState: SearchState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Up Next")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !searchState.playbackManager.queue.currentQueue.isEmpty {
                    Text("\(searchState.playbackManager.queue.queueSize) songs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Content
            if searchState.playbackManager.queue.currentQueue.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "list.bullet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No songs in queue")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Add songs to play next or add them to your queue")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                }
            } else {
                // Queue list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchState.playbackManager.queue.currentQueue.enumerated()), id: \.element.id) { index, track in
                            UpNextItemView(
                                track: track,
                                index: index,
                                isCurrentTrack: index == searchState.playbackManager.queue.currentIndex,
                                isNextTrack: index == searchState.playbackManager.queue.currentIndex + 1,
                                playbackManager: searchState.playbackManager
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UpNextItemView: View {
    let track: Track
    let index: Int
    let isCurrentTrack: Bool
    let isNextTrack: Bool
    @ObservedObject var playbackManager: PlaybackManager
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Track indicator
            ZStack {
                if isCurrentTrack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                } else if isNextTrack {
                    Text("Next")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, alignment: .center)
            
            // Thumbnail
            AsyncImage(url: URL(string: track.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrentTrack ? .blue : .primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.duration.formattedDuration)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            // Remove button (only on hover)
            if isHovered {
                Button(action: {
                    playbackManager.queue.removeFromQueue(at: index)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentTrack ? Color.blue.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            // Jump to this track
            _ = playbackManager.queue.moveToTrack(at: index)
            Task {
                await playbackManager.playCurrentTrack()
            }
        }
        .contextMenu {
            Button(action: {
                _ = playbackManager.queue.moveToTrack(at: index)
                Task {
                    await playbackManager.playCurrentTrack()
                }
            }) {
                Label("Play Now", systemImage: "play.fill")
            }
            
            Button(action: {
                playbackManager.queue.removeFromQueue(at: index)
            }) {
                Label("Remove from Queue", systemImage: "trash")
            }
        }
    }
}

#Preview {
    UpNextView(searchState: SearchState())
        .frame(width: 600, height: 400)
}