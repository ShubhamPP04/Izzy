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
    var queueList: [FavoriteSong]? = nil  // Optional queue list for filtered playback
    @State private var showingAddToPlaylist = false
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var isHovered = false // Add hover state
    
    // Use provided queue list or fall back to all favorites
    private var songsForQueue: [FavoriteSong] {
        queueList ?? searchState.favorites
    }
    
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
            .overlay(alignment: .bottomTrailing) {
                if let source = favorite.musicSource {
                    Circle()
                        .fill(MusicSource.colorForSource(source))
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 2)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(favorite.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Tidal quality badge
                    if favorite.musicSource == "tidal", let quality = favorite.audioQuality {
                        TidalQualityBadge(quality: quality)
                    }
                }
                
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
            
            // Action buttons - show on hover or in edit mode
            HStack(spacing: 8) {
                // Add to Queue button
                Button(action: {
                    // Convert FavoriteSong to Track and add to queue
                    let track = Track(
                        id: favorite.id,
                        title: favorite.title,
                        artist: favorite.artist ?? "Unknown Artist",
                        thumbnailURL: favorite.thumbnailURL,
                        duration: favorite.duration ?? 0.0,
                        videoId: favorite.videoId
                    )
                    searchState.playbackManager.queue.addToQueue(track)
                    print("🎵 Added to queue: \(favorite.title)")
                }) {
                    Image(systemName: "text.insert")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add to queue")
                
                // Download button
                Button(action: {
                    Task {
                        await DownloadManager.shared.downloadSong(favorite)
                    }
                }) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Download")
                
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
            .opacity((isHovered || editMode) ? 1.0 : 0.0) // Show on hover or in edit mode
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(searchState.playbackManager.currentTrack?.videoId == favorite.videoId ? 
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
                playCount: nil,
                musicSource: favorite.musicSource
            )
            
            // Play the song
            let track = Track(from: searchResult)
            
            // Create queue from filtered favorites (uses songsForQueue)
            let tracks = songsForQueue.map { song in
                SearchResult(
                    id: song.id,
                    type: .song,
                    title: song.title,
                    artist: song.artist,
                    thumbnailURL: song.thumbnailURL,
                    duration: song.duration,
                    explicit: false,
                    videoId: song.videoId,
                    browseId: nil,
                    year: nil,
                    playCount: nil,
                    musicSource: song.musicSource
                )
            }.map { Track(from: $0) }
            
            // Play with the filtered queue - the QueueManager will handle shuffle logic
            Task {
                await searchState.playbackManager.play(track: track, fromQueue: tracks)
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    @Binding var scrollOffset: CGFloat
    @State private var selectedFilter: SourceFilter = .all
    
    // Filtered songs based on selected source
    private var filteredFavorites: [FavoriteSong] {
        switch selectedFilter {
        case .all:
            return searchState.favorites
        case .youtubeMusic:
            return searchState.favorites.filter { $0.musicSource == "youtube_music" }
        case .jioSaavn:
            return searchState.favorites.filter { $0.musicSource == "jiosaavn" }
        case .tidal:
            return searchState.favorites.filter { $0.musicSource == "tidal" }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with enhanced styling
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                        Text("Favorites")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Your liked songs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Edit button with enhanced styling
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
            
            // Source Filter Tabs
            HStack {
                SourceFilterPicker(selectedFilter: $selectedFilter)
                Spacer()
                
                // Show count for selected filter
                Text("\(filteredFavorites.count) songs")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Favorites grid with 2 songs per row
            if filteredFavorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: selectedFilter == .all ? "heart" : selectedFilter.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text(selectedFilter == .all ? "No favorites yet" : "No \(selectedFilter.displayName) favorites")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(selectedFilter == .all ? "Start adding songs to your favorites to see them here" : "Add songs from \(selectedFilter.displayName) to your favorites")
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
                        ForEach(filteredFavorites, id: \.id) { favorite in
                            HStack {
                                // Drag handle in edit mode
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.trailing, 8)
                                
                                // Favorite item
                                FavoriteItemView(
                                    favorite: favorite,
                                    searchState: searchState,
                                    editMode: $editMode,
                                    queueList: filteredFavorites
                                )
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.horizontal, 16)
                } else {
                    // Normal view mode with grid layout
                    ScrollViewReader { scrollReader in
                        ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(filteredFavorites, id: \.id) { favorite in
                                FavoriteItemView(
                                    favorite: favorite,
                                    searchState: searchState,
                                    editMode: $editMode,
                                    queueList: filteredFavorites
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        // Removed onAppear scroll-to-top to maintain scroll position persistence
                    }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}