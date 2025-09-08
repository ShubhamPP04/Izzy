//
//  SearchResultsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

// MARK: - Playback Context

enum PlaybackContext {
    case general
    case album(String)
    case playlist(String)
}

struct SearchResultsView: View {
    @ObservedObject var musicSearchManager: MusicSearchManager
    @ObservedObject var playbackManager: PlaybackManager
    @ObservedObject var windowManager: WindowManager
    var searchState: SearchState? // Add this to access favorites functionality
    
    @State private var expandedAlbums: Set<String> = []
    @State private var expandedPlaylists: Set<String> = []
    @State private var expandedArtists: Set<String> = []
    @State private var albumTracks: [String: [SearchResult]] = [:]
    @State private var playlistTracks: [String: [SearchResult]] = [:]
    @State private var artistSongs: [String: [SearchResult]] = [:]
    @State private var expandedCategories: Set<SearchResultType> = []
    
    private let maxResultsToShow = 8
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(musicSearchManager.getResultsForDisplay(), id: \.category) { categoryData in
                    let isExpanded = expandedCategories.contains(categoryData.category)
                    let resultsToShow = isExpanded ? categoryData.results : Array(categoryData.results.prefix(maxResultsToShow))
                    
                    SearchCategorySection(
                        category: categoryData.category,
                        results: resultsToShow,
                        totalResults: categoryData.results.count,
                        isExpanded: isExpanded,
                        selectedCategory: musicSearchManager.selectedCategory,
                        selectedIndex: musicSearchManager.selectedResultIndex,
                        currentTrack: playbackManager.currentTrack,
                        expandedAlbums: $expandedAlbums,
                        expandedPlaylists: $expandedPlaylists,
                        expandedArtists: $expandedArtists,
                        albumTracks: albumTracks,
                        playlistTracks: playlistTracks,
                        artistSongs: artistSongs,
                        searchState: searchState, // Pass searchState down
                        onResultTap: { result, context in
                            handleResultSelection(result, context: context)
                        },
                        onAlbumExpand: { album in
                            handleAlbumExpansion(album)
                        },
                        onPlaylistExpand: { playlist in
                            handlePlaylistExpansion(playlist)
                        },
                        onArtistExpand: { artist in
                            handleArtistExpansion(artist)
                        },
                        onShowAllTap: { category in
                            handleShowAllTap(category)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 600)
        .background(Color.clear)
    }
    
    private func handleResultSelection(_ result: SearchResult, context: PlaybackContext = .general) {
        // Only handle songs directly - albums and playlists are handled by expansion
        guard result.type == .song || result.type == .video else { return }
        
        print("🎵 Song tapped: \(result.title) by \(result.artist ?? "Unknown")")
        
        let track = Track(from: result)
        
        // Immediately set the current track to show player controls
        playbackManager.currentTrack = track
        playbackManager.playbackState = .buffering
        
        Task {
            // Create queue based on context
            let allTracks: [Track]
            
            switch context {
            case .general:
                // Create queue from current search results - include both songs and videos
                let songsResults = musicSearchManager.searchResults.songs
                let videosResults = musicSearchManager.searchResults.videos
                let combinedResults = songsResults + videosResults
                allTracks = combinedResults.map { Track(from: $0) }
                
            case .album(let albumId):
                // Create queue from album tracks
                if let albumTrackResults = albumTracks[albumId] {
                    allTracks = albumTrackResults.map { Track(from: $0) }
                } else {
                    allTracks = [track] // Fallback to single track
                }
                
            case .playlist(let playlistId):
                // Create queue from playlist tracks
                if let playlistTrackResults = playlistTracks[playlistId] {
                    allTracks = playlistTrackResults.map { Track(from: $0) }
                } else {
                    allTracks = [track] // Fallback to single track
                }
            }
            
            print("🎵 Starting playback for: \(track.title) with \(allTracks.count) tracks in queue")
            
            // Play the selected track with the contextual queue
            await playbackManager.play(track: track, fromQueue: allTracks)
            
            print("🎵 Playback started, currentTrack should be set")
            
            // Keep window open to show playback controls
            // User can manually close with Escape or clicking outside
        }
    }
    
    private func handleAlbumExpansion(_ album: SearchResult) {
        guard let browseId = album.browseId else { return }
        
        if expandedAlbums.contains(album.id) {
            // Collapse
            expandedAlbums.remove(album.id)
            albumTracks.removeValue(forKey: album.id)
        } else {
            // Expand
            expandedAlbums.insert(album.id)
            
            Task {
                do {
                    let tracks = try await musicSearchManager.loadAlbumTracks(browseId: browseId)
                    // Inherit album cover art for tracks that don't have their own
                    let tracksWithAlbumArt = tracks.map { track in
                        var updatedTrack = track
                        if updatedTrack.thumbnailURL == nil || updatedTrack.thumbnailURL?.isEmpty == true {
                            updatedTrack = SearchResult(
                                id: track.id,
                                type: track.type,
                                title: track.title,
                                artist: track.artist,
                                thumbnailURL: album.thumbnailURL, // Use album's cover art
                                duration: track.duration,
                                explicit: track.explicit,
                                videoId: track.videoId,
                                browseId: track.browseId,
                                year: track.year,
                                playCount: track.playCount
                            )
                        }
                        return updatedTrack
                    }
                    await MainActor.run {
                        albumTracks[album.id] = tracksWithAlbumArt
                    }
                } catch {
                    print("Failed to load album tracks: \(error)")
                }
            }
        }
    }
    
    private func handlePlaylistExpansion(_ playlist: SearchResult) {
        guard let playlistId = playlist.browseId else { return }
        
        if expandedPlaylists.contains(playlist.id) {
            // Collapse
            expandedPlaylists.remove(playlist.id)
            playlistTracks.removeValue(forKey: playlist.id)
        } else {
            // Expand
            expandedPlaylists.insert(playlist.id)
            
            Task {
                do {
                    let tracks = try await musicSearchManager.loadPlaylistTracks(playlistId: playlistId)
                    await MainActor.run {
                        playlistTracks[playlist.id] = tracks
                    }
                } catch {
                    print("Failed to load playlist tracks: \(error)")
                }
            }
        }
    }
    
    private func handleArtistExpansion(_ artist: SearchResult) {
        guard let browseId = artist.browseId else { return }
        
        if expandedArtists.contains(artist.id) {
            // Collapse
            expandedArtists.remove(artist.id)
            artistSongs.removeValue(forKey: artist.id)
        } else {
            // Expand
            expandedArtists.insert(artist.id)
            
            Task {
                do {
                    let songs = try await musicSearchManager.loadArtistSongs(browseId: browseId)
                    // Inherit artist thumbnail for songs that don't have their own
                    let songsWithArtistArt = songs.map { song in
                        var updatedSong = song
                        if updatedSong.thumbnailURL == nil || updatedSong.thumbnailURL?.isEmpty == true {
                            updatedSong = SearchResult(
                                id: song.id,
                                type: song.type,
                                title: song.title,
                                artist: song.artist,
                                thumbnailURL: artist.thumbnailURL, // Use artist's thumbnail
                                duration: song.duration,
                                explicit: song.explicit,
                                videoId: song.videoId,
                                browseId: song.browseId,
                                year: song.year,
                                playCount: song.playCount
                            )
                        }
                        return updatedSong
                    }
                    await MainActor.run {
                        artistSongs[artist.id] = songsWithArtistArt
                    }
                } catch {
                    print("Failed to load artist songs: \(error)")
                }
            }
        }
    }
    
    private func handleShowAllTap(_ category: SearchResultType) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }
}

struct SearchCategorySection: View {
    let category: SearchResultType
    let results: [SearchResult]
    let totalResults: Int
    let isExpanded: Bool
    let selectedCategory: SearchResultType
    let selectedIndex: Int
    let currentTrack: Track?
    @Binding var expandedAlbums: Set<String>
    @Binding var expandedPlaylists: Set<String>
    @Binding var expandedArtists: Set<String>
    let albumTracks: [String: [SearchResult]]
    let playlistTracks: [String: [SearchResult]]
    let artistSongs: [String: [SearchResult]]
    var searchState: SearchState? // Add this parameter
    let onResultTap: (SearchResult, PlaybackContext) -> Void
    let onAlbumExpand: (SearchResult) -> Void
    let onPlaylistExpand: (SearchResult) -> Void
    let onArtistExpand: (SearchResult) -> Void
    let onShowAllTap: (SearchResultType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category Header
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(totalResults)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                // Show All button (only if there are more results than currently shown)
                if totalResults > results.count {
                    Button(action: {
                        onShowAllTap(category)
                    }) {
                        Text(isExpanded ? "Show Less" : "Show All")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
            
            // Results List
            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                VStack(spacing: 0) {
                    SearchResultRow(
                        result: result,
                        category: category,
                        isSelected: selectedCategory == category && selectedIndex == index,
                        isCurrentlyPlaying: currentTrack?.videoId == result.videoId && !(result.videoId?.isEmpty ?? true),
                        isExpanded: isExpanded(result),
                        searchState: searchState, // Pass searchState down
                        onTap: { 
                            if result.type == .album {
                                onAlbumExpand(result)
                            } else if result.type == .playlist {
                                onPlaylistExpand(result)
                            } else if result.type == .artist {
                                onArtistExpand(result)
                            } else {
                                onResultTap(result, .general)
                            }
                        }
                    )
                    
                    // Show expanded tracks for albums, playlists, and artists
                    if isExpanded(result) {
                        let tracks = getTracks(for: result)
                        if !tracks.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(tracks, id: \.id) { track in
                                    SearchResultRow(
                                        result: track,
                                        category: .song,
                                        isSelected: false,
                                        isCurrentlyPlaying: currentTrack?.videoId == track.videoId && !(track.videoId?.isEmpty ?? true),
                                        isExpanded: false,
                                        searchState: searchState, // Pass searchState down
                                        onTap: { 
                                            // Determine context based on parent result
                                            let context: PlaybackContext
                                            if result.type == .album {
                                                context = .album(result.id)
                                            } else if result.type == .playlist {
                                                context = .playlist(result.id)
                                            } else if result.type == .artist {
                                                context = .general // Artists don't have a specific context yet
                                            } else {
                                                context = .general
                                            }
                                            onResultTap(track, context)
                                        }
                                    )
                                    .padding(.leading, 20)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(result.type == .artist ? "Loading songs..." : "Loading tracks...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 20)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }
    
    private func isExpanded(_ result: SearchResult) -> Bool {
        if result.type == .album {
            return expandedAlbums.contains(result.id)
        } else if result.type == .playlist {
            return expandedPlaylists.contains(result.id)
        } else if result.type == .artist {
            return expandedArtists.contains(result.id)
        }
        return false
    }
    
    private func getTracks(for result: SearchResult) -> [SearchResult] {
        if result.type == .album {
            return albumTracks[result.id] ?? []
        } else if result.type == .playlist {
            return playlistTracks[result.id] ?? []
        } else if result.type == .artist {
            return artistSongs[result.id] ?? []
        }
        return []
    }
    
    private var categoryIcon: String {
        switch category {
        case .song: return "music.note"
        case .album: return "rectangle.stack"
        case .artist: return "person.circle"
        case .playlist: return "music.note.list"
        case .video: return "play.rectangle"
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    let category: SearchResultType
    let isSelected: Bool
    let isCurrentlyPlaying: Bool
    let isExpanded: Bool
    var searchState: SearchState? // Add this parameter
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var showingAddToPlaylist = false
    @StateObject private var playlistManager = PlaylistManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: result.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: thumbnailCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: categoryIcon)
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                    }
            }
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius))
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Title
                HStack {
                    Text(result.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if result.explicit {
                        Text("E")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    
                    Spacer()
                }
                
                // Artist/Subtitle
                if let artist = result.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Additional info
                HStack {
                    if let duration = result.duration {
                        Text(duration.formattedDuration)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let year = result.year {
                        Text("• \(year)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    if let playCount = result.playCount {
                        Text("• \(playCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Action buttons (only for songs and videos)
            if (category == .song || category == .video) && searchState != nil {
                HStack(spacing: 8) {
                    // Add to Playlist button
                    Button(action: {
                        showingAddToPlaylist = true
                    }) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isHovered ? 1.0 : 0.0)
                    .popover(isPresented: $showingAddToPlaylist) {
                        AddToPlaylistView(
                            song: result,
                            playlistManager: playlistManager,
                            searchState: searchState!,
                            isPresented: $showingAddToPlaylist
                        )
                    }
                    
                    // Favorite button
                    Button(action: {
                        searchState?.toggleFavorite(result)
                    }) {
                        Image(systemName: (searchState?.isFavorited(result) ?? false) ? "heart.fill" : "heart")
                            .foregroundColor((searchState?.isFavorited(result) ?? false) ? .red : .secondary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isHovered ? 1.0 : 0.0)
                }
            }
            
            // Expand/collapse indicator for albums, playlists, and artists
            if result.type == .album || result.type == .playlist || result.type == .artist {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColorForState)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private var backgroundColorForState: Color {
        // Only show blue background for songs that are currently playing
        if isCurrentlyPlaying && (result.type == .song || result.type == .video) {
            return Color.blue.opacity(0.3)
        } else if isSelected {
            return Color.blue.opacity(0.2)
        } else if isHovered {
            return Color.primary.opacity(0.05)
        } else {
            return Color.clear
        }
    }
    
    private var thumbnailSize: (width: CGFloat, height: CGFloat) {
        switch category {
        case .song, .video:
            return (40, 40)
        case .album, .playlist:
            return (45, 45)
        case .artist:
            return (40, 40)
        }
    }
    
    private var thumbnailCornerRadius: CGFloat {
        switch category {
        case .artist:
            return 20 // Circular for artists
        default:
            return 4
        }
    }
    
    private var categoryIcon: String {
        switch category {
        case .song: return "music.note"
        case .album: return "rectangle.stack"
        case .artist: return "person.circle"
        case .playlist: return "music.note.list"
        case .video: return "play.rectangle"
        }
    }
}

// MARK: - Search State Indicator

struct SearchStateIndicator: View {
    @ObservedObject var musicSearchManager: MusicSearchManager
    
    var body: some View {
        VStack(spacing: 8) {
            if musicSearchManager.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let error = musicSearchManager.searchError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if musicSearchManager.searchResults.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    Text("Type to search for music...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    SearchResultsView(
        musicSearchManager: MusicSearchManager(),
        playbackManager: PlaybackManager.shared,
        windowManager: WindowManager()
    )
    .frame(width: 600, height: 400)
    .background(Color.black.opacity(0.1))
}