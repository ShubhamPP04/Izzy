//
//  AISearchView.swift
//  Izzy
//
//  Created by GitHub Copilot on 26/09/25.
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                promptField
                suggestionsSection
                insightsSection
                resultsHighlightsSection
                fallbackSection
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.vertical)
            .background(GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewOffsetKey.self, value: -proxy.frame(in: .named("AISEARCHSCROLL")) .origin.y)
            })
        }
        .coordinateSpace(name: "AISEARCHSCROLL")
        .onPreferenceChange(ViewOffsetKey.self) { scrollOffset = $0 }
        .onAppear {
            viewModel.bootstrap(initialQuery: searchState.searchText)
            if viewModel.curatedResults.isEmpty {
                Task { await MainActor.run { promptFieldFocused = true } }
            }
        }
        .onChange(of: promptFieldFocused) { _, newValue in
            isPromptFocused = newValue
        }
        .onChange(of: isPromptFocused) { _, newValue in
            if newValue != promptFieldFocused {
                promptFieldFocused = newValue
            }
        }
        .onDisappear {
            isPromptFocused = false
        }
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(12)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Search")
                    .font(.system(size: 20, weight: .semibold))
                Text("Describe what you're looking for and let Izzy curate music instantly.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    private var promptField: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                TextField("Try \"energetic synthwave to stay productive\"", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .focused($promptFieldFocused)
                    .onSubmit { viewModel.submitCurrentQuery() }
                if viewModel.isSearching {
                    Text(viewModel.progressPercentageText)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                } else if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )

            if viewModel.shouldShowProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: viewModel.searchProgress) {
                        Text(viewModel.progressStatusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } currentValueLabel: {
                        Text(viewModel.progressPercentageText)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.purple)
                    .animation(.easeInOut(duration: 0.25), value: viewModel.searchProgress)
                }
                .padding(.horizontal, 4)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.pink)
            }
        }
    }
    
    private var resultsHighlightsSection: some View {
        Group {
            if viewModel.shouldShowHighlights {
                VStack(alignment: .leading, spacing: 16) {
                    songsSection
                    albumsSection
                    playlistsSection
                }
                .transition(.opacity)
            }
        }
    }

    private var suggestionsSection: some View {
        Group {
            if !viewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    AISectionHeader(title: "Smart refinements", systemImage: "sparkles")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                Button {
                                    viewModel.useSuggestion(suggestion)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(suggestion)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(LinearGradient(colors: [.purple.opacity(0.35), .blue.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        Group {
            if !viewModel.insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    AISectionHeader(title: "Highlights", systemImage: "lightbulb")
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.insights, id: \.self) { insight in
                            Label(insight, systemImage: "lightbulb.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var fallbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.shouldShowHighlights && !viewModel.isSearching {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Need inspiration?")
                        .font(.headline)
                    Text("Try prompts like \"jazzy beats for rainy evenings\" or \"soothing piano instrumentals for sleep\".")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if viewModel.hasClassicResults {
                Button {
                    openInClassicSearch(with: viewModel.inputText)
                } label: {
                    Label("Open in Classic Search", systemImage: "arrow.right.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.top, 12)
    }
    
    private func songsSectionView(results: [SearchResult]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(results, id: \.id) { result in
                AISongTile(result: result) {
                    play(result: result)
                } onOpen: {
                    openInClassicSearch(with: result.title)
                }
            }
        }
    }

    private var songsSection: some View {
        Group {
            if !viewModel.songHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    AISectionHeader(title: "Top songs", systemImage: "music.note")
                    songsSectionView(results: viewModel.songHighlights)
                }
            }
        }
    }

    private var albumsSection: some View {
        Group {
            if !viewModel.albumHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    AISectionHeader(title: "Featured albums", systemImage: "rectangle.stack.fill")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.albumHighlights, id: \.id) { album in
                                AICollectionCard(result: album, accent: .blue.opacity(0.6)) {
                                    openInClassicSearch(with: album.title)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var playlistsSection: some View {
        Group {
            if !viewModel.playlistHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    AISectionHeader(title: "Curated playlists", systemImage: "music.note.list")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.playlistHighlights, id: \.id) { playlist in
                                AICollectionCard(result: playlist, accent: .purple.opacity(0.55)) {
                                    openInClassicSearch(with: playlist.title)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func openInClassicSearch(with query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        selectedTab = 1
        searchState.searchText = query
        searchState.showResults = true
        isPromptFocused = false
        searchState.saveSelectedTab(1)
        windowManager.showWindow()
    }

    private func play(result: SearchResult) {
        guard result.type == .song, let videoId = result.videoId, !videoId.isEmpty else {
            openInClassicSearch(with: result.title)
            return
        }
        let track = Track(from: result)
        Task { await searchState.playbackManager.play(track: track) }
    }
}

private struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AISongTile: View {
    let result: SearchResult
    let onPlay: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                thumbnail
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .shadow(radius: 3, y: 1)
            }
            Text(result.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)
            if let artist = result.artist, !artist.isEmpty {
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button("Play now", action: onPlay)
            Button("Search more like this") {
                onOpen()
            }
        }
        .onTapGesture(perform: onPlay)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = result.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                ZStack {
                    Color.white.opacity(0.08)
                    ProgressView()
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct AICollectionCard: View {
    let result: SearchResult
    let accent: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                Text(result.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 160, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var subtitleText: String? {
        if let artist = result.artist, !artist.isEmpty {
            return artist
        }
        switch result.type {
        case .album:
            return "Album"
        case .playlist:
            return "Playlist"
        default:
            return nil
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlString = result.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            } placeholder: {
                placeholder
            }
            .frame(width: 136, height: 136)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            placeholder
                .frame(width: 136, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [accent.opacity(0.3), accent.opacity(0.1)], startPoint: .top, endPoint: .bottom)
            Image(systemName: placeholderIcon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var placeholderIcon: String {
        switch result.type {
        case .album:
            return "rectangle.stack"
        case .playlist:
            return "music.note.list"
        default:
            return "music.note"
        }
    }
}

private struct AISectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

private extension AISearchViewModel {
    var songHighlights: [SearchResult] {
        curatedResults.isEmpty ? Array(fullResults.songs.prefix(6)) : curatedResults
    }

    var albumHighlights: [SearchResult] {
        Array(fullResults.albums.prefix(8))
    }

    var playlistHighlights: [SearchResult] {
        Array(fullResults.playlists.prefix(8))
    }

    var shouldShowHighlights: Bool {
        !songHighlights.isEmpty || !albumHighlights.isEmpty || !playlistHighlights.isEmpty
    }

    var hasClassicResults: Bool {
        fullResults.hasResults
    }

    var progressPercentageText: String {
        let clamped = max(0, min(1, searchProgress))
        return "\(Int(clamped * 100))%"
    }

    var progressStatusText: String {
        if isSearching {
            return "Finding the perfect mix…"
        }
        if searchProgress >= 1 {
            return "Ready"
        }
        return "Preparing results…"
    }

    var shouldShowProgress: Bool {
        isSearching || searchProgress > 0
    }
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
