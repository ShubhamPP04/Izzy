//
//  AISearchView.swift
//  Izzy
//
//  Redesigned minimal AI Search. Every result is actionable:
//  - Songs: play immediately
//  - Albums: expand inline to show tracks, click track to play
//  - Artists: expand inline to show songs
//  - Playlists: expand inline to show tracks
//

import SwiftUI

struct AISearchView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    @Binding var selectedTab: Int
    @Binding var scrollOffset: CGFloat
    @Binding var isPromptFocused: Bool
    @StateObject private var viewModel = AISearchViewModel()
    @FocusState private var promptFieldFocused: Bool

    // Expandable sections state
    @State private var expandedAlbums: Set<String> = []
    @State private var expandedArtists: Set<String> = []
    @State private var expandedPlaylists: Set<String> = []
    @State private var albumTracks: [String: [SearchResult]] = [:]
    @State private var artistSongs: [String: [SearchResult]] = [:]
    @State private var playlistTracks: [String: [SearchResult]] = [:]
    @State private var isLoadingAlbum: Set<String> = []
    @State private var isLoadingArtist: Set<String> = []
    @State private var isLoadingPlaylist: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                promptSection
                resultsContent
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewOffsetKey.self, value: -proxy.frame(in: .named("AISEARCHSCROLL")).origin.y)
            })
        }
        .coordinateSpace(name: "AISEARCHSCROLL")
        .onPreferenceChange(ViewOffsetKey.self) { scrollOffset = $0 }
        .onAppear {
            viewModel.bootstrap(initialQuery: searchState.searchText)
            if viewModel.curatedResults.isEmpty {
                Task { @MainActor in promptFieldFocused = true }
            }
        }
        .onChange(of: promptFieldFocused) { _, newValue in isPromptFocused = newValue }
        .onChange(of: isPromptFocused) { _, newValue in
            if newValue != promptFieldFocused { promptFieldFocused = newValue }
        }
        .onDisappear { isPromptFocused = false }
    }

    // MARK: - Prompt

    private var promptSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isAppleIntelligenceAvailable ? "apple.intelligence" : "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TextField("Describe what you want to hear...", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($promptFieldFocused)
                    .onSubmit { viewModel.submitCurrentQuery() }

                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else if !viewModel.inputText.isEmpty {
                    Button(action: viewModel.clear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsContent: some View {
        if viewModel.shouldShowHighlights {
            VStack(spacing: 24) {
                if !viewModel.songHighlights.isEmpty {
                    songSection
                }
                if !viewModel.albumHighlights.isEmpty {
                    albumSection
                }
                if !viewModel.artistHighlights.isEmpty {
                    artistSection
                }
                if !viewModel.playlistHighlights.isEmpty {
                    playlistSection
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if !viewModel.isSearching {
            emptyState
        }
    }

    // MARK: - Songs

    private var songSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Songs")
            ForEach(viewModel.songHighlights, id: \.id) { song in
                ResultRow(result: song) {
                    playSong(song)
                }
            }
        }
    }

    // MARK: - Albums

    private var albumSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Albums")
            ForEach(viewModel.albumHighlights, id: \.id) { album in
                VStack(spacing: 0) {
                    ResultRow(result: album, isExpanded: expandedAlbums.contains(album.id)) {
                        toggleAlbum(album)
                    }

                    if expandedAlbums.contains(album.id) {
                        if isLoadingAlbum.contains(album.id) {
                            HStack {
                                Spacer()
                                ProgressView().controlSize(.small)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else if let tracks = albumTracks[album.id] {
                            VStack(spacing: 0) {
                                ForEach(tracks, id: \.id) { track in
                                    ResultRow(result: track, isNested: true) {
                                        playSong(track)
                                    }
                                }
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Artists

    private var artistSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Artists")
            ForEach(viewModel.artistHighlights, id: \.id) { artist in
                VStack(spacing: 0) {
                    ResultRow(result: artist, isExpanded: expandedArtists.contains(artist.id)) {
                        toggleArtist(artist)
                    }

                    if expandedArtists.contains(artist.id) {
                        if isLoadingArtist.contains(artist.id) {
                            HStack {
                                Spacer()
                                ProgressView().controlSize(.small)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else if let songs = artistSongs[artist.id] {
                            VStack(spacing: 0) {
                                ForEach(songs, id: \.id) { song in
                                    ResultRow(result: song, isNested: true) {
                                        playSong(song)
                                    }
                                }
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Playlists

    private var playlistSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("Playlists")
            ForEach(viewModel.playlistHighlights, id: \.id) { playlist in
                VStack(spacing: 0) {
                    ResultRow(result: playlist, isExpanded: expandedPlaylists.contains(playlist.id)) {
                        togglePlaylist(playlist)
                    }

                    if expandedPlaylists.contains(playlist.id) {
                        if isLoadingPlaylist.contains(playlist.id) {
                            HStack {
                                Spacer()
                                ProgressView().controlSize(.small)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else if let tracks = playlistTracks[playlist.id] {
                            VStack(spacing: 0) {
                                ForEach(tracks, id: \.id) { track in
                                    ResultRow(result: track, isNested: true) {
                                        playSong(track)
                                    }
                                }
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            if viewModel.isAppleIntelligenceNotReady {
                Label("Apple Intelligence not available on this device", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.orange.opacity(0.08)))
            }

            VStack(spacing: 8) {
                Text("Try a natural language query")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\"chill jazz for studying\"  \"best of Queen\"  \"80s synthwave\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    // MARK: - Actions

    private func playSong(_ result: SearchResult) {
        guard result.type == .song, let videoId = result.videoId, !videoId.isEmpty else { return }
        let track = Track(from: result)
        Task { await searchState.playbackManager.play(track: track) }
    }

    private func toggleAlbum(_ album: SearchResult) {
        if expandedAlbums.contains(album.id) {
            expandedAlbums.remove(album.id)
            albumTracks.removeValue(forKey: album.id)
        } else {
            expandedAlbums.insert(album.id)
            guard let browseId = album.browseId, !browseId.isEmpty else { return }
            isLoadingAlbum.insert(album.id)
            Task {
                do {
                    let tracks = try await searchState.musicSearchManager.loadAlbumTracks(browseId: browseId)
                    let inherited = tracks.map { track in
                        var t = track
                        if t.thumbnailURL == nil || t.thumbnailURL?.isEmpty == true {
                            t = SearchResult(id: track.id, type: track.type, title: track.title, artist: track.artist, thumbnailURL: album.thumbnailURL, duration: track.duration, explicit: track.explicit, videoId: track.videoId, browseId: track.browseId, year: track.year, playCount: track.playCount, musicSource: track.musicSource, audioQuality: track.audioQuality)
                        }
                        return t
                    }
                    await MainActor.run {
                        albumTracks[album.id] = inherited
                        isLoadingAlbum.remove(album.id)
                    }
                } catch {
                    print("Failed to load album tracks: \(error)")
                    await MainActor.run { isLoadingAlbum.remove(album.id) }
                }
            }
        }
    }

    private func toggleArtist(_ artist: SearchResult) {
        if expandedArtists.contains(artist.id) {
            expandedArtists.remove(artist.id)
            artistSongs.removeValue(forKey: artist.id)
        } else {
            expandedArtists.insert(artist.id)
            guard let browseId = artist.browseId, !browseId.isEmpty else { return }
            isLoadingArtist.insert(artist.id)
            Task {
                do {
                    let songs = try await searchState.musicSearchManager.loadArtistSongs(browseId: browseId)
                    let inherited = songs.map { song in
                        var s = song
                        if s.thumbnailURL == nil || s.thumbnailURL?.isEmpty == true {
                            s = SearchResult(id: song.id, type: song.type, title: song.title, artist: song.artist, thumbnailURL: artist.thumbnailURL, duration: song.duration, explicit: song.explicit, videoId: song.videoId, browseId: song.browseId, year: song.year, playCount: song.playCount, musicSource: song.musicSource, audioQuality: song.audioQuality)
                        }
                        return s
                    }
                    await MainActor.run {
                        artistSongs[artist.id] = inherited
                        isLoadingArtist.remove(artist.id)
                    }
                } catch {
                    print("Failed to load artist songs: \(error)")
                    await MainActor.run { isLoadingArtist.remove(artist.id) }
                }
            }
        }
    }

    private func togglePlaylist(_ playlist: SearchResult) {
        if expandedPlaylists.contains(playlist.id) {
            expandedPlaylists.remove(playlist.id)
            playlistTracks.removeValue(forKey: playlist.id)
        } else {
            expandedPlaylists.insert(playlist.id)
            let playlistId = playlist.id
            isLoadingPlaylist.insert(playlist.id)
            Task {
                do {
                    let tracks = try await searchState.musicSearchManager.loadPlaylistTracks(playlistId: playlistId)
                    await MainActor.run {
                        playlistTracks[playlist.id] = tracks
                        isLoadingPlaylist.remove(playlist.id)
                    }
                } catch {
                    print("Failed to load playlist tracks: \(error)")
                    await MainActor.run { isLoadingPlaylist.remove(playlist.id) }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.quaternary)
            .padding(.leading, 4)
            .padding(.bottom, 2)
    }
}

// MARK: - Result Row (universal row for all types)

private struct ResultRow: View {
    let result: SearchResult
    var isExpanded: Bool = false
    var isNested: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                artwork(size: isNested ? 32 : 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(.system(size: isNested ? 12 : 13, weight: .medium))
                        .lineLimit(1)
                    if let artist = result.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        typeLabel
                    }
                }

                Spacer()

                trailingIcon
            }
            .padding(.horizontal, isNested ? 8 : 10)
            .padding(.vertical, isNested ? 6 : 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.04) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var typeLabel: some View {
        switch result.type {
        case .album:
            Text("Album").font(.system(size: 10)).foregroundStyle(.secondary)
        case .artist:
            Text("Artist").font(.system(size: 10)).foregroundStyle(.secondary)
        case .playlist:
            Text("Playlist").font(.system(size: 10)).foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingIcon: some View {
        switch result.type {
        case .song:
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.quaternary)
        case .album, .artist, .playlist:
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.quaternary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func artwork(size: CGFloat) -> some View {
        Group {
            if let urlString = result.thumbnailURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
            } else {
                Color.secondary.opacity(0.1)
                    .overlay(
                        Image(systemName: iconForType)
                            .font(.system(size: size * 0.35))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: result.type == .artist ? size / 2 : 5, style: .continuous))
    }

    private var iconForType: String {
        switch result.type {
        case .album: return "rectangle.stack"
        case .artist: return "person.fill"
        case .playlist: return "music.note.list"
        default: return "music.note"
        }
    }
}

// MARK: - Preference Key

private struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - ViewModel Extensions

private extension AISearchViewModel {
    var songHighlights: [SearchResult] {
        curatedResults.isEmpty ? Array(fullResults.songs.prefix(6)) : curatedResults
    }
    var albumHighlights: [SearchResult] { Array(fullResults.albums.prefix(6)) }
    var artistHighlights: [SearchResult] { Array(fullResults.artists.prefix(4)) }
    var playlistHighlights: [SearchResult] { Array(fullResults.playlists.prefix(4)) }
    var shouldShowHighlights: Bool {
        !songHighlights.isEmpty || !albumHighlights.isEmpty || !artistHighlights.isEmpty || !playlistHighlights.isEmpty
    }
    var hasClassicResults: Bool { fullResults.hasResults }
}

#Preview {
    AISearchView(
        searchState: SearchState(),
        windowManager: WindowManager(),
        selectedTab: Binding.constant(7),
        scrollOffset: Binding.constant(CGFloat.zero),
        isPromptFocused: Binding.constant(false)
    )
    .frame(width: 560)
    .padding()
    .background(Color.black)
}
