//
//  FavoritesView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct FavoriteItemView: View {
    let favorite: FavoriteSong
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
            AsyncImage(url: URL(string: favorite.thumbnailURL ?? "")) { image in
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
                Text(favorite.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let artist = favorite.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let duration = favorite.duration {
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
                        
                        AddToPlaylistView(
                            song: searchResult,
                            playlistManager: playlistManager,
                            searchState: searchState,
                            isPresented: $showingAddToPlaylist
                        )
                    }
                    
                    // Remove favorite button
                    Button(action: {
                        // Create a SearchResult from the favorite to remove it
                        let searchResult = SearchResult(
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
                        searchState.removeFavorite(searchResult)
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
                .fill(searchState.playbackManager.currentTrack?.videoId == favorite.videoId ? 
                      Color.blue.opacity(0.3) : Color.primary.opacity(0.05))
        )
        .onTapGesture {
            guard !editMode else { return }
            
            // Play the song directly
            let searchResult = SearchResult(
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
            
            // Play the song
            let track = Track(from: searchResult)
            Task {
                await searchState.playbackManager.play(track: track, fromQueue: [track])
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Favorites")
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
            
            // Favorites list
            if searchState.favorites.isEmpty {
                HStack {
                    Text("No favorites yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                List {
                    ForEach(searchState.favorites, id: \.id) { favorite in
                        FavoriteItemView(
                            favorite: favorite,
                            searchState: searchState,
                            editMode: $editMode
                        )
                    }
                    .onMove { indices, newOffset in
                        if editMode {
                            searchState.reorderFavorites(from: indices.first!, to: newOffset)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}