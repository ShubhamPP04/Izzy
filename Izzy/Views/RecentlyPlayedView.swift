//
//  RecentlyPlayedView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

// MARK: - Source Filter Enum
enum SourceFilter: String, CaseIterable {
    case all = "All"
    case youtubeMusic = "youtube_music"
    case jioSaavn = "jiosaavn"
    case tidal = "tidal"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .youtubeMusic: return "YouTube Music"
        case .jioSaavn: return "JioSaavn"
        case .tidal: return "Tidal"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "music.note.list"
        case .youtubeMusic: return "play.circle.fill"
        case .jioSaavn: return "music.note"
        case .tidal: return "waveform"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .youtubeMusic: return .red
        case .jioSaavn: return .green
        case .tidal: return MusicSource.tidal.color
        }
    }
}

// MARK: - Source Filter Picker View
struct SourceFilterPicker: View {
    @Binding var selectedFilter: SourceFilter
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(SourceFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 11))
                        Text(filter.displayName)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedFilter == filter ? filter.color.opacity(0.2) : Color.primary.opacity(0.05))
                    )
                    .foregroundColor(selectedFilter == filter ? filter.color : .secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedFilter == filter ? filter.color.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct RecentlyPlayedItemView: View {
    let recentlyPlayed: FavoriteSong
    @ObservedObject var searchState: SearchState
    @Binding var editMode: Bool
    var queueList: [FavoriteSong]? = nil  // Optional queue list for filtered playback
    @State private var showingAddToPlaylist = false
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var isHovered = false // Add hover state
    
    // Use provided queue list or fall back to all recently played
    private var songsForQueue: [FavoriteSong] {
        queueList ?? searchState.recentlyPlayed
    }
    
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
            .overlay(alignment: .bottomTrailing) {
                if let source = recentlyPlayed.musicSource {
                    Circle()
                        .fill(MusicSource.colorForSource(source))
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 2)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(recentlyPlayed.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Quality badge for Tidal tracks
                    if recentlyPlayed.musicSource == "tidal", let quality = recentlyPlayed.audioQuality {
                        TidalQualityBadge(quality: quality)
                    }
                }
                
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
                // Add to Queue button
                Button(action: {
                    // Convert RecentlyPlayedSong to Track and add to queue
                    let track = Track(
                        id: recentlyPlayed.id,
                        title: recentlyPlayed.title,
                        artist: recentlyPlayed.artist ?? "Unknown Artist",
                        thumbnailURL: recentlyPlayed.thumbnailURL,
                        duration: recentlyPlayed.duration ?? 0.0,
                        videoId: recentlyPlayed.videoId
                    )
                    searchState.playbackManager.queue.addToQueue(track)
                    print("🎵 Added to queue: \(recentlyPlayed.title)")
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
                        await DownloadManager.shared.downloadSong(recentlyPlayed)
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
                playCount: nil,
                musicSource: recentlyPlayed.musicSource
            )
            
            // Play the song
            let track = Track(from: searchResult)
            
            // Create queue from filtered recently played songs (uses songsForQueue)
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

struct RecentlyPlayedView: View {
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    @Binding var scrollOffset: CGFloat
    @State private var selectedFilter: SourceFilter = .all
    
    // Filtered songs based on selected source
    private var filteredRecentlyPlayed: [FavoriteSong] {
        switch selectedFilter {
        case .all:
            return searchState.recentlyPlayed
        case .youtubeMusic:
            return searchState.recentlyPlayed.filter { $0.musicSource == "youtube_music" }
        case .jioSaavn:
            return searchState.recentlyPlayed.filter { $0.musicSource == "jiosaavn" }
        case .tidal:
            return searchState.recentlyPlayed.filter { $0.musicSource == "tidal" }
        }
    }
    
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
            
            // Source Filter Tabs
            HStack {
                SourceFilterPicker(selectedFilter: $selectedFilter)
                Spacer()
                
                // Show count for selected filter
                Text("\(filteredRecentlyPlayed.count) songs")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Recently played grid with 2 songs per row
            if filteredRecentlyPlayed.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: selectedFilter == .all ? "clock" : selectedFilter.icon)
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Text(selectedFilter == .all ? "No recently played songs yet" : "No \(selectedFilter.displayName) songs")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(selectedFilter == .all ? "Play some songs to see them appear here" : "Play some songs from \(selectedFilter.displayName) to see them here")
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
                        ForEach(filteredRecentlyPlayed, id: \.id) { recentlyPlayed in
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
                                    editMode: $editMode,
                                    queueList: filteredRecentlyPlayed
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
                            ForEach(filteredRecentlyPlayed, id: \.id) { recentlyPlayed in
                                RecentlyPlayedItemView(
                                    recentlyPlayed: recentlyPlayed,
                                    searchState: searchState,
                                    editMode: $editMode,
                                    queueList: filteredRecentlyPlayed
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