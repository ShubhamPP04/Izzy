//
//  QueueView.swift
//  Izzy
//
//  Created by Qoder on 12/09/25.
//

import SwiftUI

struct QueueView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Queue")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Queue list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(playbackManager.queue.currentQueue.enumerated()), id: \.element.id) { index, track in
                        QueueItemView(
                            track: track,
                            index: index,
                            isCurrentTrack: index == playbackManager.queue.currentIndex,
                            playbackManager: playbackManager,
                            onDismiss: {
                                isPresented = false
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Footer with queue info
            HStack {
                Text("\(playbackManager.queue.queueSize) songs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    playbackManager.queue.clearQueue()
                    isPresented = false
                }) {
                    Text("Clear Queue")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(radius: 5)
        )
    }
}

struct QueueItemView: View {
    let track: Track
    let index: Int
    let isCurrentTrack: Bool
    @ObservedObject var playbackManager: PlaybackManager
    var onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator
            if isCurrentTrack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                    .frame(width: 20, alignment: .center)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .center)
            }
            
            // Song thumbnail
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
                            .font(.system(size: 12))
                    }
            }
            .frame(width: 30, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 13, weight: isCurrentTrack ? .semibold : .medium))
                    .foregroundColor(isCurrentTrack ? .blue : .primary)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.duration.formattedDuration)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Remove button
            Button(action: {
                playbackManager.queue.removeFromQueue(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCurrentTrack ? Color.blue.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            // Play this track
            if playbackManager.queue.moveToTrack(at: index) {
                Task {
                    await playbackManager.playCurrentTrack()
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    QueueView(playbackManager: PlaybackManager.shared, isPresented: .constant(true))
}