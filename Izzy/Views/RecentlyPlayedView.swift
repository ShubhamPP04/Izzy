//
//  RecentlyPlayedView.swift
//  Izzy
//

import SwiftUI

struct RecentlyPlayedView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Recently Played")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(searchState.recentlyPlayed.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                if !searchState.recentlyPlayed.isEmpty {
                    // Clear All button (only shown in edit mode)
                    if editMode {
                        if showingClearConfirmation {
                            // Custom confirmation view instead of alert
                            HStack(spacing: 8) {
                                Text("Clear all?")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                                
                                Button("Yes") {
                                    searchState.clearRecentlyPlayed()
                                    showingClearConfirmation = false
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .buttonStyle(PlainButtonStyle())
                                
                                Button("No") {
                                    showingClearConfirmation = false
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                                .buttonStyle(PlainButtonStyle())
                            }
                        } else {
                            Button(action: {
                                // Show confirmation dialog before clearing all
                                showingClearConfirmation = true
                            }) {
                                Text("Clear All")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Button(action: {
                        editMode.toggle()
                        // Reset confirmation state when toggling edit mode
                        showingClearConfirmation = false
                    }) {
                        Text(editMode ? "Done" : "Edit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
            
            // Recently played grid/list
            if searchState.recentlyPlayed.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    Text("No recently played songs yet. Play some music to see them here.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                if editMode {
                    // Reorderable list view
                    List {
                        ForEach(searchState.recentlyPlayed) { recentlyPlayed in
                            HStack {
                                // Drag handle
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.trailing, 8)
                                
                                // Recently played item
                                RecentlyPlayedItemView(recentlyPlayed: recentlyPlayed, searchState: searchState)
                                
                                Spacer()
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                        }
                        .onMove { indices, newOffset in
                            // Convert recently played to a mutable array
                            var recentlyPlayedArray = searchState.recentlyPlayed
                            
                            // Perform the move operation
                            recentlyPlayedArray.move(fromOffsets: indices, toOffset: newOffset)
                            
                            // Update the searchState with the new order
                            searchState.recentlyPlayed = recentlyPlayedArray
                            searchState.saveRecentlyPlayed()
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    // Grid view
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(searchState.recentlyPlayed) { recentlyPlayed in
                                RecentlyPlayedItemView(recentlyPlayed: recentlyPlayed, searchState: searchState)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct RecentlyPlayedItemView: View {
    let recentlyPlayed: FavoriteSong
    @ObservedObject var searchState: SearchState
    
    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: recentlyPlayed.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(recentlyPlayed.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let artist = recentlyPlayed.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let duration = recentlyPlayed.duration {
                    Text(duration.formattedDuration)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Remove recently played button
            Button(action: {
                searchState.removeRecentlyPlayed(recentlyPlayed)
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(searchState.playbackManager.currentTrack?.videoId == recentlyPlayed.videoId ? 
                      Color.blue.opacity(0.3) : Color.primary.opacity(0.05))
        )
        .onTapGesture {
            // Create a SearchResult from the recently played to play it
            let searchResult = SearchResult(
                id: recentlyPlayed.id,
                type: .song,
                title: recentlyPlayed.title,
                artist: recentlyPlayed.artist,
                thumbnailURL: recentlyPlayed.thumbnailURL,
                duration: recentlyPlayed.duration,
                explicit: false,
                videoId: recentlyPlayed.videoId,
                browseId: nil,
                year: nil,
                playCount: nil
            )
            
            // Play the recently played song
            Task {
                let track = Track(from: searchResult)
                
                // Create queue from all recently played in their current order
                let allTracks = searchState.recentlyPlayed.map { favorite in
                    SearchResult(
                        id: favorite.id,
                        type: .song,
                        title: favorite.title,
                        artist: favorite.artist,
                        thumbnailURL: favorite.thumbnailURL,
                        duration: favorite.duration,
                        explicit: false,
                        videoId: favorite.videoId,
                        browseId: nil,
                        year: nil,
                        playCount: nil
                    )
                }.map { Track(from: $0) }
                
                // Find the index of the selected track in the queue
                let startIndex = allTracks.firstIndex { $0.id == track.id } ?? 0
                
                // Set up the queue starting from the selected track
                await searchState.playbackManager.play(track: track, fromQueue: Array(allTracks[startIndex...]))
            }
        }
    }
}

#Preview {
    RecentlyPlayedView(searchState: SearchState())
        .frame(width: 600, height: 400)
        .background(Color.black.opacity(0.1))
}