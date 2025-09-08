//
//  PlaylistView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var searchState: SearchState
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var showingCreatePlaylist = false
    @State private var selectedPlaylist: Playlist? = nil
    @State private var newPlaylistName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if selectedPlaylist != nil {
                    // Back button when viewing playlist songs
                    Button(action: {
                        selectedPlaylist = nil
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(selectedPlaylist?.name ?? "Playlist")
                        .font(.title2)
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Playlists")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingCreatePlaylist = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 5)
            
            // Create Playlist Form (shown in-app instead of sheet)
            if showingCreatePlaylist {
                CreatePlaylistViewInApp(
                    isPresented: $showingCreatePlaylist,
                    playlistManager: playlistManager
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            
            // Playlist content
            if playlistManager.playlists.isEmpty && !showingCreatePlaylist && selectedPlaylist == nil {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No playlists yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Create your first playlist to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Playlist") {
                        showingCreatePlaylist = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if !showingCreatePlaylist {
                if let playlist = selectedPlaylist {
                    // Show songs in the selected playlist
                    PlaylistSongsView(playlist: playlist, searchState: searchState)
                } else {
                    // Show list of playlists
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(playlistManager.playlists) { playlist in
                                PlaylistItemView(
                                    playlist: playlist, 
                                    playlistManager: playlistManager, 
                                    searchState: searchState,
                                    onPlaylistSelected: { selectedPlaylist = $0 }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            print("🎵 PlaylistView appeared")
        }
    }
}

struct PlaylistItemView: View {
    let playlist: Playlist
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var searchState: SearchState
    @State private var showingOptions = false
    var onPlaylistSelected: (Playlist) -> Void
    
    // Computed property to get the playlist cover image
    private var playlistCoverURL: String {
        // If playlist has a thumbnailURL, use it
        if let thumbnailURL = playlist.thumbnailURL, !thumbnailURL.isEmpty {
            return thumbnailURL
        }
        // Otherwise, use the first song's thumbnail if available
        else if let firstSong = playlist.songs.first, let firstSongThumbnail = firstSong.thumbnailURL, !firstSongThumbnail.isEmpty {
            return firstSongThumbnail
        }
        // Fallback to empty string
        else {
            return ""
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail - use first song's artwork if playlist doesn't have one
            AsyncImage(url: URL(string: playlistCoverURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                // Make the playlist name tappable
                Text(playlist.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .onTapGesture {
                        onPlaylistSelected(playlist)
                    }
                
                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("\(playlist.songCount) songs")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    if playlist.songCount > 0 {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text(playlist.totalDuration.formattedDuration)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Options button
            Button(action: {
                showingOptions = true
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: $showingOptions) {
                PlaylistOptionsView(playlist: playlist, playlistManager: playlistManager, searchState: searchState, isPresented: $showingOptions)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
        )
        .onTapGesture {
            // Navigate to playlist songs view
            onPlaylistSelected(playlist)
            print("🎵 Tapped on playlist: \(playlist.name)")
        }
    }
}

struct PlaylistSongsView: View {
    let playlist: Playlist
    @ObservedObject var searchState: SearchState
    @State private var editMode = false
    @StateObject private var playlistManager = PlaylistManager.shared
    @State private var currentSongs: [FavoriteSong] = []
    @State private var displayedPlaylist: Playlist? = nil
    
    // Computed property to get the playlist cover image
    private var playlistCoverURL: String {
        // If we have a displayed playlist, use its data
        if let displayedPlaylist = displayedPlaylist {
            // If playlist has a thumbnailURL, use it
            if let thumbnailURL = displayedPlaylist.thumbnailURL, !thumbnailURL.isEmpty {
                return thumbnailURL
            }
            // Otherwise, use the first song's thumbnail if available
            else if let firstSong = displayedPlaylist.songs.first, let firstSongThumbnail = firstSong.thumbnailURL, !firstSongThumbnail.isEmpty {
                return firstSongThumbnail
            }
            // Fallback to empty string
            else {
                return ""
            }
        }
        
        // If playlist has a thumbnailURL, use it
        if let thumbnailURL = playlist.thumbnailURL, !thumbnailURL.isEmpty {
            return thumbnailURL
        }
        // Otherwise, use the first song's thumbnail if available
        else if let firstSong = playlist.songs.first, let firstSongThumbnail = firstSong.thumbnailURL, !firstSongThumbnail.isEmpty {
            return firstSongThumbnail
        }
        // Fallback to empty string
        else {
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Playlist header with artwork
            HStack(spacing: 16) {
                // Playlist artwork - use first song's artwork if playlist doesn't have one
                AsyncImage(url: URL(string: playlistCoverURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note.list")
                                .foregroundColor(.secondary)
                                .font(.title2)
                        )
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 8) {
                    // Make the playlist name tappable to play the playlist
                    Text(displayedPlaylist?.name ?? playlist.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .onTapGesture {
                            playPlaylist()
                        }
                    
                    if let description = displayedPlaylist?.description ?? playlist.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("\((displayedPlaylist ?? playlist).songCount) songs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if (displayedPlaylist ?? playlist).songCount > 0 {
                            Text("•")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text((displayedPlaylist ?? playlist).totalDuration.formattedDuration)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            // Play entire playlist
                            playPlaylist()
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Play")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        if !(displayedPlaylist ?? playlist).songs.isEmpty {
                            Button(action: {
                                let wasInEditMode = editMode
                                editMode.toggle()
                                
                                // When exiting edit mode, refresh the playlist data
                                if wasInEditMode && !editMode {
                                    // Get the updated playlist from the manager
                                    if let updatedPlaylist = playlistManager.getPlaylist(by: playlist.id) {
                                        // Update the displayed playlist and local songs array
                                        displayedPlaylist = updatedPlaylist
                                        currentSongs = updatedPlaylist.songs
                                    }
                                }
                                // When entering edit mode, initialize the songs array
                                else if !wasInEditMode && editMode {
                                    // Use the displayed playlist if available, otherwise use the original
                                    let playlistToUse = displayedPlaylist ?? playlist
                                    if let updatedPlaylist = playlistManager.getPlaylist(by: playlistToUse.id) {
                                        currentSongs = updatedPlaylist.songs
                                    } else {
                                        currentSongs = playlistToUse.songs
                                    }
                                }
                            }) {
                                Text(editMode ? "Done" : "Edit")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Divider()
            
            // Songs list
            if (editMode ? currentSongs : (displayedPlaylist ?? playlist).songs).isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No songs in this playlist")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add songs to this playlist from search results, favorites, or recently played")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                if editMode {
                    // Edit mode with drag and drop reordering
                    List {
                        ForEach($currentSongs, id: \.videoId) { $song in
                            HStack {
                                // Drag handle in edit mode
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 16, weight: .medium))
                                    .padding(.trailing, 8)
                                
                                // Song item
                                PlaylistSongItemView(
                                    song: song,
                                    index: currentSongs.firstIndex(where: { $0.videoId == song.videoId }) ?? 0,
                                    playlist: displayedPlaylist ?? playlist,
                                    searchState: searchState,
                                    editMode: $editMode,
                                    onRemove: {
                                        // Update the local songs array when a song is removed
                                        if let index = currentSongs.firstIndex(where: { $0.videoId == song.videoId }) {
                                            currentSongs.remove(at: index)
                                        }
                                    }
                                )
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onMove { indices, newOffset in
                            // Move the songs in the local array
                            currentSongs.move(fromOffsets: indices, toOffset: newOffset)
                            
                            // Update the playlist in the manager
                            playlistManager.moveSongsInPlaylist(
                                playlistId: playlist.id,
                                from: indices,
                                to: newOffset
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                    .padding(.horizontal, 16)
                } else {
                    // Normal view mode
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array((displayedPlaylist ?? playlist).songs.enumerated()), id: \.element.videoId) { index, song in
                                PlaylistSongItemView(
                                    song: song,
                                    index: index,
                                    playlist: displayedPlaylist ?? playlist,
                                    searchState: searchState,
                                    editMode: $editMode
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .onChange(of: playlistManager.playlists) { newValue in
            // Update the local songs when the playlist manager changes
            if editMode, let updatedPlaylist = newValue.first(where: { $0.id == playlist.id }) {
                currentSongs = updatedPlaylist.songs
            }
            // Also update the displayed playlist when not in edit mode
            else if !editMode, let updatedPlaylist = newValue.first(where: { $0.id == playlist.id }) {
                displayedPlaylist = updatedPlaylist
            }
        }
        .onAppear {
            // Initialize the local songs array and displayed playlist
            currentSongs = playlist.songs
            displayedPlaylist = playlist
        }
    }
    
    private func playPlaylist() {
        let playlistToUse = displayedPlaylist ?? playlist
        guard !playlistToUse.songs.isEmpty else { return }
        
        // Convert FavoriteSong to Track
        let tracks = playlistToUse.songs.map { favoriteSong in
            SearchResult(
                id: favoriteSong.id,
                type: .song,
                title: favoriteSong.title,
                artist: favoriteSong.artist,
                thumbnailURL: favoriteSong.thumbnailURL,
                duration: favoriteSong.duration,
                explicit: false,
                videoId: favoriteSong.videoId,
                browseId: nil,
                year: nil,
                playCount: nil
            )
        }.map { Track(from: $0) }
        
        // Play first track with the entire playlist as queue
        if let firstTrack = tracks.first {
            Task {
                await searchState.playbackManager.play(track: firstTrack, fromQueue: tracks)
            }
        }
    }
}

struct PlaylistSongItemView: View {
    let song: FavoriteSong
    let index: Int
    let playlist: Playlist
    @ObservedObject var searchState: SearchState
    @Binding var editMode: Bool
    @StateObject private var playlistManager = PlaylistManager.shared
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number (only shown when not in edit mode)
            if !editMode {
                Text("\(index + 1)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .center)
            }
            
            // Song thumbnail
            AsyncImage(url: URL(string: song.thumbnailURL ?? "")) { image in
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
            
            // Song info
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let artist = song.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            if let duration = song.duration {
                Text(duration.formattedDuration)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if editMode {
                // Remove button in edit mode
                Button(action: {
                    // Remove song from playlist
                    playlistManager.removeSongFromPlaylist(songVideoId: song.videoId, playlistId: playlist.id)
                    // Notify the parent view that a song was removed
                    onRemove?()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(searchState.playbackManager.currentTrack?.videoId == song.videoId ? 
                      Color.blue.opacity(0.3) : Color.clear)
        )
        .onTapGesture {
            guard !editMode else { return }
            
            // Convert FavoriteSong to Track and play
            let searchResult = SearchResult(
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
                playCount: nil
            )
            
            let track = Track(from: searchResult)
            
            // Create queue from all songs in the playlist
            let tracks = playlist.songs.map { favoriteSong in
                SearchResult(
                    id: favoriteSong.id,
                    type: .song,
                    title: favoriteSong.title,
                    artist: favoriteSong.artist,
                    thumbnailURL: favoriteSong.thumbnailURL,
                    duration: favoriteSong.duration,
                    explicit: false,
                    videoId: favoriteSong.videoId,
                    browseId: nil,
                    year: nil,
                    playCount: nil
                )
            }.map { Track(from: $0) }
            
            Task {
                await searchState.playbackManager.play(track: track, fromQueue: tracks)
            }
        }
    }
}

struct PlaylistOptionsView: View {
    let playlist: Playlist
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var searchState: SearchState
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Options")
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
            
            // Options
            VStack(spacing: 0) {
                Button(action: {
                    // TODO: Implement play next
                    isPresented = false
                    print("⏭️ Play next: \(playlist.name)")
                }) {
                    HStack {
                        Image(systemName: "text.insert")
                            .font(.system(size: 14))
                        Text("Play Next")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // TODO: Implement add to queue
                    isPresented = false
                    print("➕ Add to Queue: \(playlist.name)")
                }) {
                    HStack {
                        Image(systemName: "plus.rectangle.on.rectangle")
                            .font(.system(size: 14))
                        Text("Add to Queue")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                
                Button(action: {
                    // Delete playlist
                    playlistManager.deletePlaylist(playlist)
                    isPresented = false
                    print("🗑️ Deleted playlist: \(playlist.name)")
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("Delete")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(width: 250)
    }
}

struct CreatePlaylistView: View {
    @Binding var isPresented: Bool
    @ObservedObject var playlistManager: PlaylistManager
    @State private var playlistName = ""
    @State private var playlistDescription = ""
    
    var body: some View {
        VStack {
            Text("New Playlist")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist Name")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("My Playlist", text: $playlistName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Description", text: $playlistDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Create") {
                    if !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let newPlaylist = playlistManager.createPlaylist(
                            name: playlistName,
                            description: playlistDescription.isEmpty ? nil : playlistDescription
                        )
                        print("🎵 Created new playlist: \(newPlaylist.name)")
                        // Clear the fields after creation
                        playlistName = ""
                        playlistDescription = ""
                        // Only dismiss after successful creation
                        isPresented = false
                    }
                }
                .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
        .onDisappear {
            // Reset fields when view disappears
            playlistName = ""
            playlistDescription = ""
        }
    }
}

struct CreatePlaylistViewInApp: View {
    @Binding var isPresented: Bool
    @ObservedObject var playlistManager: PlaylistManager
    @State private var playlistName = ""
    @State private var playlistDescription = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("New Playlist")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist Name")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("My Playlist", text: $playlistName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                TextField("Description", text: $playlistDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Create") {
                    if !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let newPlaylist = playlistManager.createPlaylist(
                            name: playlistName,
                            description: playlistDescription.isEmpty ? nil : playlistDescription
                        )
                        print("🎵 Created new playlist: \(newPlaylist.name)")
                        // Clear the fields after creation
                        playlistName = ""
                        playlistDescription = ""
                        // Close the form
                        isPresented = false
                    }
                }
                .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(radius: 5)
        )
    }
}

#Preview {
    PlaylistView(searchState: SearchState())
        .frame(width: 600, height: 650)
}