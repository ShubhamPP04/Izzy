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
    
    var body: some View {
        HStack(spacing: 8) {
            if editMode {
                // Drag handle in edit mode
                Image(systemName: "line.horizontal.3")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.trailing, 8)
            }
            
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
            
            if editMode {
                // Action buttons in edit mode
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
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(searchState.playbackManager.currentTrack?.videoId == recentlyPlayed.videoId ? 
                      Color.blue.opacity(0.3) : Color.primary.opacity(0.05))
        )
        .onTapGesture {
            guard !editMode else { return }
            
            // Play the song directly
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
            Task {
                await searchState.playbackManager.play(track: track, fromQueue: [track])
            }
        }
    }
}

struct RecentlyPlayedView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recently Played")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Edit button
                Button(action: {
                    withAnimation {
                        editMode.toggle()
                    }
                }) {
                    Text(editMode ? "Done" : "Edit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Recently played list
            if searchState.recentlyPlayed.isEmpty {
                HStack {
                    Text("No recently played songs yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                List {
                    ForEach(searchState.recentlyPlayed, id: \.id) { recentlyPlayed in
                        RecentlyPlayedItemView(
                            recentlyPlayed: recentlyPlayed,
                            searchState: searchState,
                            editMode: $editMode
                        )
                    }
                    .onMove { indices, newOffset in
                        if editMode {
                            // We don't reorder recently played songs, they're always sorted by most recent
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}