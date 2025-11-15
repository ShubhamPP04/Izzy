//
//  HomeView.swift
//  Izzy
//
//  Created by GitHub Copilot on 07/09/25.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var playlistManager = PlaylistManager.shared
    @Binding var selectedTab: Int
    @Binding var scrollOffset: CGFloat
    @State private var forYouSongs: [FavoriteSong] = []
    @State private var refreshTrigger = 0
    @State private var shownSongIds: Set<String> = [] // Track songs that have been shown
    @State private var isLoadingRecommendations = false
    @State private var hasInitiallyLoaded = false
    @AppStorage("musicSource") private var musicSource = MusicSource.youtubeMusic.rawValue

    // Computed property for dynamic greeting based on time of day
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<21:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    // Get personalized recommendations based on listening history and current source
    private func getForYouRecommendations(forceRefresh: Bool = false) async {
        guard !isLoadingRecommendations else { return }

        isLoadingRecommendations = true
        defer {
            isLoadingRecommendations = false
            hasInitiallyLoaded = true
        }

        let recentlyPlayed = searchState.recentlyPlayed
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"

        // Filter by current source only
        let filteredSongs = recentlyPlayed.filter { $0.musicSource == currentSource }

        guard !filteredSongs.isEmpty else {
            // No recently played songs available
            await MainActor.run {
                forYouSongs = []
            }
            return
        }

        let pythonService = PythonServiceManager.shared
        var newRecommendations: [FavoriteSong] = []

        // If force refresh, clear a portion of shown IDs to allow fresh content
        if forceRefresh {
            print("🔄 Force refresh - clearing shown song history")
            shownSongIds.removeAll()
        }

        // Try AI-powered recommendations first if Gemini API key is available
        print("🔑 Checking Gemini API key availability: \(pythonService.hasGeminiAPIKey)")

        if pythonService.hasGeminiAPIKey && !forceRefresh {
            // Use AI only on initial load, not on force refresh for faster performance
            do {
                // Build a concise AI query based on recently played songs
                let recentArtists = Array(Set(filteredSongs.prefix(5).compactMap { $0.artist })).prefix(3).joined(separator: ", ")
                let recentTitles = filteredSongs.prefix(3).map { $0.title }.joined(separator: ", ")

                let aiQuery = "Similar to: \(recentTitles) by \(recentArtists)"

                print("🤖 AI ENABLED - Fetching recommendations")

                let aiResponse = try await pythonService.performAISearch(query: aiQuery, limit: 12)

                // Convert AI results to FavoriteSong and filter out already shown
                for result in aiResponse.topResults {
                    guard let videoId = result.videoId else { continue }

                    // Skip if already shown or already in recently played
                    if shownSongIds.contains(videoId) ||
                       filteredSongs.contains(where: { $0.videoId == videoId }) ||
                       newRecommendations.contains(where: { $0.videoId == videoId }) {
                        continue
                    }

                    let favoriteSong = FavoriteSong(from: result)
                    newRecommendations.append(favoriteSong)

                    if newRecommendations.count >= 10 {
                        break
                    }
                }

                print("✅ AI returned \(newRecommendations.count) fresh recommendations")
            } catch {
                print("⚠️ AI search failed, falling back to regular suggestions: \(error)")
            }
        }

        // Use song suggestions API (faster method) - run in parallel for speed
        if newRecommendations.count < 10 {
            await withTaskGroup(of: [FavoriteSong].self) { group in
                // Launch parallel tasks for multiple songs
                for song in filteredSongs.prefix(3) {
                    let videoId = song.videoId
                    guard !videoId.isEmpty else { continue }

                    group.addTask {
                        do {
                            let suggestions = try await pythonService.getSongSuggestions(videoId: videoId)

                            // Convert and filter suggestions
                            var results: [FavoriteSong] = []
                            for suggestion in suggestions.prefix(20) {
                                guard let suggestionVideoId = suggestion.videoId else { continue }

                                // Skip if already shown or in recently played
                                if shownSongIds.contains(suggestionVideoId) ||
                                   filteredSongs.contains(where: { $0.videoId == suggestionVideoId }) {
                                    continue
                                }

                                results.append(FavoriteSong(from: suggestion))

                                if results.count >= 15 {
                                    break
                                }
                            }
                            return results
                        } catch {
                            print("Failed to get suggestions for \(song.title): \(error)")
                            return []
                        }
                    }
                }

                // Collect results from all parallel tasks
                for await suggestions in group {
                    for suggestion in suggestions {
                        // Check again to avoid duplicates from parallel tasks
                        if !newRecommendations.contains(where: { $0.videoId == suggestion.videoId }) {
                            newRecommendations.append(suggestion)
                        }

                        if newRecommendations.count >= 10 {
                            break
                        }
                    }

                    if newRecommendations.count >= 10 {
                        break
                    }
                }
            }
        }

        // If we still don't have enough, supplement with shuffled unshown recent songs
        if newRecommendations.count < 10 {
            let remainingNeeded = 10 - newRecommendations.count
            let unshownRecent = filteredSongs.filter { song in
                let videoId = song.videoId
                return !videoId.isEmpty &&
                       !shownSongIds.contains(videoId) &&
                       !newRecommendations.contains(where: { $0.videoId == videoId })
            }

            newRecommendations.append(contentsOf: unshownRecent.shuffled().prefix(remainingNeeded))
        }

        // Update shown song IDs
        for song in newRecommendations {
            let videoId = song.videoId
            if !videoId.isEmpty {
                shownSongIds.insert(videoId)
            }
        }

        // Reset shown IDs if we've shown too many (keep only last 100)
        if shownSongIds.count > 100 {
            let recentIds = Set(newRecommendations.map { $0.videoId }.filter { !$0.isEmpty })
            shownSongIds = recentIds
        }

        // Only update if we got new recommendations
        if !newRecommendations.isEmpty {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    forYouSongs = newRecommendations
                }
            }
        }
    }

    // Get source display name
    private var currentSourceName: String {
        let currentSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        return currentSource == "youtube_music" ? "YouTube Music" : "JioSaavn"
    }
    
    var body: some View {
        ScrollViewReader { scrollReader in
            ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Welcome section with more minimal design
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(greeting),")
                        .font(.largeTitle)
                        .fontWeight(.light)
                        .foregroundColor(.primary)

                    Text(UserDefaults.standard.string(forKey: "customHomeName") ?? "User")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)

                // For You Section - Personalized Recommendations (Horizontal Scrolling)
                // Always show the section, even if initially loading
                if hasInitiallyLoaded || !searchState.recentlyPlayed.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("For You")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    // AI badge when Gemini API key is available
                                    if PythonServiceManager.shared.hasGeminiAPIKey {
                                        HStack(spacing: 3) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 10, weight: .semibold))
                                            Text("AI")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.purple, .blue],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                        )
                                    }
                                }

                                Text("From \(currentSourceName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Refresh button with loading state
                            Button(action: {
                                if !isLoadingRecommendations {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                        refreshTrigger += 1
                                    }
                                    Task {
                                        await getForYouRecommendations(forceRefresh: true)
                                    }
                                }
                            }) {
                                ZStack {
                                    if isLoadingRecommendations {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 14, weight: .medium))
                                            .rotationEffect(.degrees(Double(refreshTrigger) * 360))
                                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: refreshTrigger)
                                    }
                                }
                                .foregroundColor(.blue)
                                .frame(width: 20, height: 20)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help(isLoadingRecommendations ? "Loading recommendations..." : "Refresh recommendations")
                            .disabled(isLoadingRecommendations)
                        }
                        .padding(.horizontal, 20)

                        // Horizontal scrolling songs
                        if forYouSongs.isEmpty && isLoadingRecommendations {
                            // Show loading placeholders
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        VStack(alignment: .leading, spacing: 8) {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 120, height: 120)
                                                .overlay(
                                                    ProgressView()
                                                )

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 120, height: 12)

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(.ultraThinMaterial)
                                                .frame(width: 80, height: 10)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        } else if !forYouSongs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(forYouSongs, id: \.id) { song in
                                        ForYouSongCard(
                                            song: song,
                                            searchState: searchState
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                                .opacity(isLoadingRecommendations ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isLoadingRecommendations)
                            }
                        } else {
                            // Empty state
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("Play some songs to get recommendations")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 40)
                                Spacer()
                            }
                        }
                    }
                }

                // Quick Actions Grid with more elegant design
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ], spacing: 20) {
                    // Search Quick Action
                    ElegantQuickActionCard(
                        icon: "magnifyingglass",
                        title: "Search",
                        subtitle: "Find music",
                        color: .blue
                    ) {
                        selectedTab = 1 // Switch to Search tab
                    }
                    
                    // Favorites Quick Action
                    ElegantQuickActionCard(
                        icon: "heart.fill",
                        title: "Favorites",
                        subtitle: "Liked songs",
                        color: .red
                    ) {
                        selectedTab = 2 // Switch to Favorites tab
                    }
                    
                    // Recently Played Quick Action
                    ElegantQuickActionCard(
                        icon: "clock.fill",
                        title: "Recently Played",
                        subtitle: "Continue listening",
                        color: .green
                    ) {
                        selectedTab = 3 // Switch to Recently Played tab
                    }
                    
                    // Playlists Quick Action
                    ElegantQuickActionCard(
                        icon: "music.note.list",
                        title: "Playlists",
                        subtitle: "Your collections",
                        color: .purple
                    ) {
                        selectedTab = 5 // Switch to Playlists tab
                    }
                }
                .padding(.horizontal, 20)
                
                // Now Playing Section (if there's a current track) - more minimal
                if let currentTrack = searchState.playbackManager.currentTrack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Now Playing")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
                            // Album Art with AsyncImage
                            AsyncImage(url: URL(string: currentTrack.thumbnailURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .foregroundColor(.secondary)
                                            .font(.title3)
                                    )
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentTrack.title)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                Text(currentTrack.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Play/Pause button with more elegant design
                            Button(action: {
                                if searchState.playbackManager.isPlaying {
                                    searchState.playbackManager.pause()
                                } else {
                                    searchState.playbackManager.resume()
                                }
                            }) {
                                Image(systemName: searchState.playbackManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Stats section with more minimal design
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Music")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        ElegantStatCard(
                            icon: "heart.fill",
                            value: "\(searchState.favorites.count)",
                            label: "Favorites",
                            color: .red
                        )
                        
                        ElegantStatCard(
                            icon: "clock.fill",
                            value: "\(searchState.recentlyPlayed.count)",
                            label: "Recent",
                            color: .green
                        )
                        
                        ElegantStatCard(
                            icon: "music.note.list",
                            value: "\(playlistManager.playlists.count)",
                            label: "Playlists",
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Load For You recommendations when view appears
            Task {
                await getForYouRecommendations()
            }
        }
        .onChange(of: musicSource) { _ in
            // Update recommendations when music source changes
            print("🔄 Music source changed in HomeView, refreshing For You recommendations")
            // Clear shown IDs when source changes to get fresh recommendations
            shownSongIds.removeAll()
            Task {
                await getForYouRecommendations()
            }
        }
        // Removed onAppear scroll-to-top to maintain scroll position persistence
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        // Track scroll position changes
                        // This is a simplified tracking approach for iOS 14
                    }
            }
        )
        }
    }
}

// For You Song Card - YouTube Music style horizontal card
struct ForYouSongCard: View {
    let song: FavoriteSong
    @ObservedObject var searchState: SearchState
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            // Play the song
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

            // Create queue from all for you songs
            let tracks = searchState.recentlyPlayed.map { song in
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
                    playCount: nil
                )
            }.map { Track(from: $0) }

            Task {
                await searchState.playbackManager.play(track: track, fromQueue: tracks)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: song.thumbnailURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            )
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Play icon overlay on hover
                    if isHovered {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 36, height: 36)

                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .shadow(color: Color.black.opacity(0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)

                // Song info
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let artist = song.artist {
                        Text(artist)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// More elegant quick action card with minimal design
struct ElegantQuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 120)
            .modifier(QuickActionCardBackgroundModifier())
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
    }
}

// More elegant stat card with minimal design
struct ElegantStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .modifier(StatCardBackgroundModifier())
    }
}

#Preview {
    HomeView(
        searchState: SearchState(),
        windowManager: WindowManager(),
        selectedTab: Binding.constant(0),
        scrollOffset: Binding.constant(0)
    )
    .frame(width: 600, height: 650)
    .background(Color.black.opacity(0.3))
}

// Conditional background modifier for quick action cards
struct QuickActionCardBackgroundModifier: ViewModifier {
    @ObservedObject private var liquidGlassSettings = LiquidGlassSettings.shared
    
    func body(content: Content) -> some View {
        if liquidGlassSettings.isEnabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.clear)
                )
                .liquidGlass(isInteractive: true, cornerRadius: 16, intensity: 0.25)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
        }
    }
}

// Conditional background modifier for stat cards
struct StatCardBackgroundModifier: ViewModifier {
    @ObservedObject private var liquidGlassSettings = LiquidGlassSettings.shared
    
    func body(content: Content) -> some View {
        if liquidGlassSettings.isEnabled {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.clear)
                )
                .liquidGlass(isInteractive: false, cornerRadius: 16, intensity: 0.2)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
        }
    }
}