//
//  FavoritesView.swift
//  Izzy
//

import SwiftUI

struct FavoritesView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Favorites")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(searchState.favorites.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                if !searchState.favorites.isEmpty {
                    Button(action: {
                        editMode.toggle()
                    }) {
                        Text(editMode ? "Done" : "Edit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
            
            // Favorites grid/list
            if searchState.favorites.isEmpty {
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    Text("No favorites yet. Hover over songs and click the heart to add favorites.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                if editMode {
                    // Reorderable list view
                    List {
                        ForEach(searchState.favorites) { favorite in
                            HStack {
                                // Drag handle
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.trailing, 8)
                                
                                // Favorite item
                                FavoriteItemView(favorite: favorite, searchState: searchState)
                                
                                Spacer()
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                        }
                        .onMove { indices, newOffset in
                            // Convert favorites to a mutable array
                            var favoritesArray = searchState.favorites
                            
                            // Perform the move operation
                            favoritesArray.move(fromOffsets: indices, toOffset: newOffset)
                            
                            // Update the searchState with the new order
                            searchState.updateFavoritesOrder(favoritesArray)
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
                            ForEach(searchState.favorites) { favorite in
                                FavoriteItemView(favorite: favorite, searchState: searchState)
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

struct FavoriteItemView: View {
    let favorite: FavoriteSong
    @ObservedObject var searchState: SearchState
    
    var body: some View {
        HStack(spacing: 8) {
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
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(searchState.playbackManager.currentTrack?.videoId == favorite.videoId ? 
                      Color.blue.opacity(0.3) : Color.primary.opacity(0.05))
        )
        .onTapGesture {
            // Create a SearchResult from the favorite to play it
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
            
            // Play the favorite song in the order of the favorites list
            Task {
                let track = Track(from: searchResult)
                
                // Create queue from all favorites in their current order
                let allTracks = searchState.favorites.map { favorite in
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
    FavoritesView(searchState: SearchState())
        .frame(width: 600, height: 400)
        .background(Color.black.opacity(0.1))
}