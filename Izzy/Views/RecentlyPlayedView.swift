//
//  RecentlyPlayedView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct RecentlyPlayedItemView: View {
    let recentlyPlayed: FavoriteSong
    @ObservedObject var searchState: SearchState
    @Binding var editMode: Bool
    @State private var showingAddToPlaylist = false
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var isHovered = false // Add hover state
    
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
                    .foregroundColor(
                        recentlyPlayed.musicSource == "jiosaavn" ? 
                        Color.green : 
                        Color.primary
                    )
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
            
            // Action buttons - show on hover or in edit mode
            HStack(spacing: 8) {
                // Add to Playlist button
                Button(action: {
                    showingAddToPlaylist = true
                }) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingAddToPlaylist) {
                    // Convert FavoriteSong to SearchResult for the AddToPlaylistView
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
                    
                    AddToPlaylistView(
                        song: searchResult,
                        playlistManager: playlistManager,
                        searchState: searchState,
                        isPresented: $showingAddToPlaylist
                    )
                }
                
                // Remove recently played button
                Button(action: {
                    searchState.removeRecentlyPlayed(recentlyPlayed)
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 4)
            .opacity((isHovered || editMode) ? 1.0 : 0.0) // Show on hover or in edit mode
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(searchState.playbackManager.currentTrack?.videoId == recentlyPlayed.videoId ? 
                      Color.blue.opacity(0.3) : Color.primary.opacity(0.05))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            guard !editMode else { return }
            
            // Play the song with proper shuffle support
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
            
            // Play the song
            let track = Track(from: searchResult)
            
            // Create queue from all recently played songs
            let tracks = searchState.recentlyPlayed.map { recentlyPlayed in
                SearchResult(
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
            }.map { Track(from: $0) }
            
            // Play with the full queue - the QueueManager will handle shuffle logic
            Task {
                await searchState.playbackManager.play(track: track, fromQueue: tracks)
            }
        }
    }
}

struct RecentlyPlayedView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with enhanced styling
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        Text("Recently Played")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Your recently played songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Edit button with enhanced styling
                if editMode {
                    // Clear All button in edit mode
                    Button(action: {
                        // Clear all recently played songs
                        searchState.recentlyPlayed.removeAll()
                        searchState.saveRecentlyPlayed()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Clear All")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.1))
                        )
                        .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 6)
                }
                
                Button(action: {
                    withAnimation {
                        editMode.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: editMode ? "checkmark" : "pencil")
                        Text(editMode ? "Done" : "Edit")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Recently played grid with 2 songs per row
            if searchState.recentlyPlayed.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text("No recently played songs yet")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Play some songs to see them appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
            } else {
                if editMode {
                    // Edit mode with drag and drop reordering using List
                    List {
                        ForEach($searchState.recentlyPlayed, id: \.id) { $recentlyPlayed in
                            HStack {
                                // Drag handle in edit mode
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.trailing, 8)
                                
                                // Recently played item
                                RecentlyPlayedItemView(
                                    recentlyPlayed: recentlyPlayed,
                                    searchState: searchState,
                                    editMode: $editMode
                                )
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { indices, newOffset in
                            // Update the order in the search state
                            searchState.recentlyPlayed.move(fromOffsets: indices, toOffset: newOffset)
                            searchState.updateRecentlyPlayedOrder(searchState.recentlyPlayed)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.horizontal, 16)
                } else {
                    // Normal view mode with grid layout
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(searchState.recentlyPlayed, id: \.id) { recentlyPlayed in
                                RecentlyPlayedItemView(
                                    recentlyPlayed: recentlyPlayed,
                                    searchState: searchState,
                                    editMode: $editMode
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}