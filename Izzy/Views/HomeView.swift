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
    @State private var forYouScrollOffset: CGFloat = 0
    @State private var canScrollLeft = false
    @State private var canScrollRight = false
    
    // Use cached data from SearchState instead of local state
    private var homeSections: [HomeSection] {
        get { searchState.cachedHomeSections }
    }
    private var chartsData: ChartsData? {
        get { searchState.cachedChartsData }
    }
    private var moodCategories: [String: [MoodCategory]] {
        get { searchState.cachedMoodCategories }
    }
    
    @State private var isLoadingHome = false
    @State private var isLoadingCharts = false
    @State private var isLoadingMoods = false

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

        print("🎵 FOR YOU: Getting recommendations for \(currentSource)")
        print("🎵 FOR YOU: Total recently played: \(recentlyPlayed.count)")

        // Filter by current source only
        let filteredSongs = recentlyPlayed.filter { $0.musicSource == currentSource }

        print("🎵 FOR YOU: Filtered to \(filteredSongs.count) songs from \(currentSource)")

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

                print("🤖 AI returned \(aiResponse.topResults.count) results")

                // Convert AI results to FavoriteSong and filter out already shown
                for result in aiResponse.topResults {
                    guard let videoId = result.videoId else { continue }

                    // STRICT: Only accept if musicSource matches OR if not set (then we set it)
                    if let resultSource = result.musicSource {
                        if resultSource != currentSource {
                            print("⚠️ AI: Skipping \(result.title) - wrong source: \(resultSource) != \(currentSource)")
                            continue
                        }
                    }

                    // Skip if already shown or already in recently played
                    if shownSongIds.contains(videoId) ||
                       filteredSongs.contains(where: { $0.videoId == videoId }) ||
                       newRecommendations.contains(where: { $0.videoId == videoId }) {
                        continue
                    }

                    let favoriteSong = FavoriteSong(from: result, musicSource: currentSource)
                    print("✅ AI: Added \(favoriteSong.title) from \(favoriteSong.musicSource ?? "unknown")")
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

                            print("💡 Suggestions: Got \(suggestions.count) results for videoId \(videoId)")

                            // Convert and filter suggestions
                            var results: [FavoriteSong] = []
                            for suggestion in suggestions.prefix(20) {
                                guard let suggestionVideoId = suggestion.videoId else { continue }

                                // STRICT: Only accept if musicSource matches OR if not set (then we set it)
                                if let resultSource = suggestion.musicSource {
                                    if resultSource != currentSource {
                                        print("⚠️ Suggestions: Skipping \(suggestion.title) - wrong source: \(resultSource) != \(currentSource)")
                                        continue
                                    }
                                }

                                // Skip if already shown or in recently played
                                if shownSongIds.contains(suggestionVideoId) ||
                                   filteredSongs.contains(where: { $0.videoId == suggestionVideoId }) {
                                    continue
                                }

                                let favSong = FavoriteSong(from: suggestion, musicSource: currentSource)
                                print("✅ Suggestions: Added \(favSong.title) from \(favSong.musicSource ?? "unknown")")
                                results.append(favSong)

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

        // Final safety check: Filter to ensure only songs from current source
        newRecommendations = newRecommendations.filter { $0.musicSource == currentSource }

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
                    // Reset scroll position and update button states
                    forYouScrollOffset = 0
                    canScrollLeft = false
                    canScrollRight = newRecommendations.count > 3
                }
            }
            print("✅ Updated For You with \(newRecommendations.count) songs from \(currentSource)")
        } else {
            print("⚠️ No recommendations found for \(currentSource)")
        }
    }

    // Get source display name
    private var currentSourceName: String {
        switch musicSource {
        case "youtube_music": return "YouTube Music"
        case "jiosaavn": return "JioSaavn"
        case "tidal": return "Tidal"
        default: return "YouTube Music"
        }
    }
    
    // MARK: - Explore Data Loading
    
    /// Load all explore sections (home, charts, moods)
    private func loadExploreData() async {
        // Use SearchState's flag to prevent reloading on window toggle
        guard !searchState.hasLoadedExploreData else { 
            print("📦 Using cached explore data")
            return 
        }
        
        // Load sections sequentially to avoid overwhelming the Python service
        await loadHomeSections()
        await loadCharts()
        await loadMoodCategories()
        
        await MainActor.run {
            searchState.hasLoadedExploreData = true
        }
    }
    
    /// Load home feed sections
    private func loadHomeSections() async {
        guard !isLoadingHome else { return }
        
        await MainActor.run {
            isLoadingHome = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingHome = false
            }
        }
        
        do {
            let pythonService = PythonServiceManager.shared
            let sections = try await pythonService.getHomeFeed()
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    searchState.cachedHomeSections = sections
                }
            }
            print("🏠 Loaded \(sections.count) home sections")
        } catch {
            print("❌ Failed to load home sections: \\(error)")
        }
    }
    
    /// Load charts data
    private func loadCharts() async {
        guard !isLoadingCharts else { return }
        
        await MainActor.run {
            isLoadingCharts = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingCharts = false
            }
        }
        
        do {
            let pythonService = PythonServiceManager.shared
            let country = musicSource == "jiosaavn" ? "IN" : "ZZ"
            let charts = try await pythonService.getCharts(country: country)
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    searchState.cachedChartsData = charts
                }
            }
            print("📊 Loaded charts with \(charts.songs.count) songs")
        } catch {
            print("❌ Failed to load charts: \(error)")
        }
    }
    
    /// Load mood categories
    private func loadMoodCategories() async {
        guard !isLoadingMoods else { return }
        
        await MainActor.run {
            isLoadingMoods = true
        }
        
        defer {
            Task { @MainActor in
                isLoadingMoods = false
            }
        }
        
        do {
            let pythonService = PythonServiceManager.shared
            let categories = try await pythonService.getMoodCategories()
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    searchState.cachedMoodCategories = categories
                }
            }
            print("🎭 Loaded \(categories.count) mood categories")
        } catch {
            print("❌ Failed to load mood categories: \(error)")
        }
    }
    
    /// Refresh all explore data
    private func refreshExploreData() async {
        searchState.hasLoadedExploreData = false
        searchState.cachedHomeSections = []
        searchState.cachedChartsData = nil
        searchState.cachedMoodCategories = [:]
        await loadExploreData()
    }
    
    /// Get icon for section title
    private func sectionIcon(for title: String) -> String {
        let lowercased = title.lowercased()
        if lowercased.contains("trending") {
            return "flame.fill"
        } else if lowercased.contains("new") || lowercased.contains("release") {
            return "sparkles"
        } else if lowercased.contains("chart") || lowercased.contains("top") {
            return "chart.bar.fill"
        } else if lowercased.contains("playlist") || lowercased.contains("featured") {
            return "music.note.list"
        } else if lowercased.contains("album") {
            return "square.stack.fill"
        } else if lowercased.contains("artist") {
            return "person.2.fill"
        } else {
            return "music.note"
        }
    }
    
    var body: some View {
        // Show playlist detail view when a playlist is selected
        if searchState.selectedExplorePlaylist != nil {
            ExplorePlaylistDetailView(
                playlist: searchState.selectedExplorePlaylist!,
                searchState: searchState
            )
        } else {
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
                            ZStack(alignment: .center) {
                                ScrollViewReader { scrollReader in
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(forYouSongs.indices, id: \.self) { index in
                                                ForYouSongCard(
                                                    song: forYouSongs[index],
                                                    forYouSongs: forYouSongs,
                                                    searchState: searchState
                                                )
                                                .id(index)
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .opacity(isLoadingRecommendations ? 0.5 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: isLoadingRecommendations)
                                    }
                                    .onAppear {
                                        canScrollLeft = false
                                        canScrollRight = forYouSongs.count > 3
                                    }

                                    // Left scroll button
                                    HStack {
                                        if canScrollLeft {
                                            Button(action: {
                                                let currentIndex = Int(forYouScrollOffset)
                                                let targetIndex = max(0, currentIndex - 3)
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    scrollReader.scrollTo(targetIndex, anchor: .leading)
                                                    forYouScrollOffset = CGFloat(targetIndex)
                                                    canScrollLeft = targetIndex > 0
                                                    canScrollRight = targetIndex < forYouSongs.count - 3
                                                }
                                            }) {
                                                Image(systemName: "chevron.left")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(
                                                        Circle()
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(
                                                                Circle()
                                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                            )
                                                    )
                                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(.leading, 8)
                                        }

                                        Spacer()

                                        // Right scroll button
                                        if canScrollRight {
                                            Button(action: {
                                                let currentIndex = Int(forYouScrollOffset)
                                                let targetIndex = min(forYouSongs.count - 1, currentIndex + 3)
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    scrollReader.scrollTo(targetIndex, anchor: .trailing)
                                                    forYouScrollOffset = CGFloat(targetIndex)
                                                    canScrollLeft = targetIndex > 0
                                                    canScrollRight = targetIndex < forYouSongs.count - 3
                                                }
                                            }) {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 32, height: 32)
                                                    .background(
                                                        Circle()
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(
                                                                Circle()
                                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                            )
                                                    )
                                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(.trailing, 8)
                                        }
                                    }
                                }
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

                // MARK: - Explore Sections (Charts, Trending, Moods)
                
                // Charts Section - Top songs
                if !isLoadingCharts {
                    if let charts = chartsData, !charts.songs.isEmpty {
                        ExploreSectionView(
                            title: "Top Charts",
                            subtitle: "Most popular right now",
                            icon: "chart.line.uptrend.xyaxis",
                            items: Array(charts.songs.prefix(15)),
                            searchState: searchState,
                            isLoading: isLoadingCharts,
                            onRefresh: {
                                searchState.cachedChartsData = nil
                                await loadCharts()
                            }
                        )
                    }
                } else {
                    ExploreSectionLoadingView(title: "Top Charts")
                }
                
                // Home Sections - Dynamic sections from API
                ForEach(homeSections) { section in
                    ExploreSectionView(
                        title: section.title,
                        subtitle: nil,
                        icon: sectionIcon(for: section.title),
                        items: Array(section.contents.prefix(15)),
                        searchState: searchState,
                        isLoading: isLoadingHome,
                        onRefresh: {
                            searchState.cachedHomeSections = []
                            await loadHomeSections()
                        }
                    )
                }
                
                // Loading placeholder for home sections
                if isLoadingHome && homeSections.isEmpty {
                    ExploreSectionLoadingView(title: "Trending")
                    ExploreSectionLoadingView(title: "New Releases")
                }
                
                // Moods & Genres Section
                if !moodCategories.isEmpty {
                    MoodsAndGenresSection(
                        moodCategories: moodCategories,
                        searchState: searchState,
                        isLoading: isLoadingMoods,
                        onRefresh: {
                            searchState.cachedMoodCategories = [:]
                            await loadMoodCategories()
                        }
                    )
                } else if isLoadingMoods {
                    ExploreSectionLoadingView(title: "Moods & Genres")
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
            // Load Explore sections (charts, home, moods)
            Task {
                await loadExploreData()
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
            // Also refresh explore data for new source
            Task {
                await refreshExploreData()
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
        } // End else block for playlist detail view
    }
}

// For You Song Card - YouTube Music style horizontal card
struct ForYouSongCard: View {
    let song: FavoriteSong
    let forYouSongs: [FavoriteSong] // All "For You" songs for queue
    @ObservedObject var searchState: SearchState
    @State private var isHovered = false

    var body: some View {
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
                    VStack {
                        HStack {
                            Spacer()
                            // Download button
                            Button(action: {
                                Task {
                                    await DownloadManager.shared.downloadSong(song)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Download")
                        }
                        .padding(6)
                        
                        Spacer()
                        
                        // Play button
                        Button(action: {
                            playSong()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 36, height: 36)

                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, 6)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: Color.black.opacity(0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                playSong()
            }

            // Song info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(song.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Tidal quality badge
                    if song.musicSource == "tidal", let quality = song.audioQuality {
                        TidalQualityBadge(quality: quality)
                    }
                }

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
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private func playSong() {
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

        // Create queue from "For You" songs (same source as current song)
        let tracks = forYouSongs.map { song in
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

// MARK: - Explore Section Views

/// Horizontal scrolling explore section for songs/albums/playlists with scroll arrows
struct ExploreSectionView: View {
    let title: String
    let subtitle: String?
    let icon: String
    let items: [SearchResult]
    @ObservedObject var searchState: SearchState
    var isLoading: Bool = false
    var onRefresh: (() async -> Void)? = nil
    
    @State private var scrollOffset: CGFloat = 0
    @State private var canScrollLeft = false
    @State private var canScrollRight = true
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Refresh button
                if onRefresh != nil {
                    Button(action: {
                        guard !isRefreshing && !isLoading else { return }
                        isRefreshing = true
                        Task {
                            await onRefresh?()
                            await MainActor.run {
                                isRefreshing = false
                            }
                        }
                    }) {
                        ZStack {
                            if isRefreshing || isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh \(title)")
                    .disabled(isRefreshing || isLoading)
                }
            }
            .padding(.horizontal, 20)
            
            // Horizontal scroll content with navigation arrows
            ZStack(alignment: .center) {
                ScrollViewReader { scrollReader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(items.indices, id: \.self) { index in
                                ExploreSongCard(
                                    item: items[index],
                                    allItems: items,
                                    searchState: searchState
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear {
                        canScrollLeft = false
                        canScrollRight = items.count > 3
                    }
                    
                    // Navigation arrows overlay
                    HStack {
                        // Left scroll button
                        if canScrollLeft {
                            Button(action: {
                                let currentIndex = Int(scrollOffset)
                                let targetIndex = max(0, currentIndex - 3)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollReader.scrollTo(targetIndex, anchor: .leading)
                                    scrollOffset = CGFloat(targetIndex)
                                    canScrollLeft = targetIndex > 0
                                    canScrollRight = targetIndex < items.count - 3
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 8)
                        }
                        
                        Spacer()
                        
                        // Right scroll button
                        if canScrollRight {
                            Button(action: {
                                let currentIndex = Int(scrollOffset)
                                let targetIndex = min(items.count - 1, currentIndex + 3)
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollReader.scrollTo(targetIndex, anchor: .trailing)
                                    scrollOffset = CGFloat(targetIndex)
                                    canScrollLeft = targetIndex > 0
                                    canScrollRight = targetIndex < items.count - 3
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.trailing, 8)
                        }
                    }
                }
            }
        }
    }
}

/// Song card for explore sections
struct ExploreSongCard: View {
    let item: SearchResult
    let allItems: [SearchResult]
    @ObservedObject var searchState: SearchState
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Image(systemName: iconForType)
                                .foregroundColor(.secondary)
                                .font(.title3)
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Play icon overlay on hover
                if isHovered {
                    VStack {
                        HStack {
                            Spacer()
                            // Download button
                            Button(action: {
                                Task {
                                    await DownloadManager.shared.downloadSong(item)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Download")
                        }
                        .padding(6)
                        
                        Spacer()
                        
                        // Play button
                        Button(action: {
                            playItem()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, 6)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Duration badge for songs
                if item.type == .song, let duration = item.duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .padding(6)
                }
            }
            .shadow(color: Color.black.opacity(0.2), radius: isHovered ? 8 : 4, x: 0, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                playItem()
            }
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Tidal quality badge
                    if item.musicSource == "tidal", let quality = item.audioQuality {
                        TidalQualityBadge(quality: quality)
                    }
                }
                
                if let artist = item.artist {
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
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private var iconForType: String {
        switch item.type {
        case .song: return "music.note"
        case .album: return "square.stack"
        case .playlist: return "music.note.list"
        case .artist: return "person.fill"
        case .video: return "play.rectangle.fill"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func playItem() {
        print("🎵 ExploreSongCard.playItem() - Type: \(item.type), Title: \(item.title), VideoId: \(item.videoId ?? "nil"), MusicSource: \(item.musicSource ?? "nil")")
        switch item.type {
        case .song, .video:
            let track = Track(from: item)
            print("🎵 Playing song/video: \(track.title), VideoId: \(track.videoId), MusicSource: \(track.musicSource ?? "nil")")
            let tracks = allItems.filter { $0.type == .song || $0.type == .video }.map { Track(from: $0) }
            Task {
                await searchState.playbackManager.play(track: track, fromQueue: tracks)
            }
        case .album:
            // Load album tracks
            if let browseId = item.browseId {
                Task {
                    do {
                        let tracks = try await PythonServiceManager.shared.getAlbumTracks(browseId: browseId)
                        if let firstTrack = tracks.first {
                            let track = Track(from: firstTrack)
                            let allTracks = tracks.map { Track(from: $0) }
                            await searchState.playbackManager.play(track: track, fromQueue: allTracks)
                        }
                    } catch {
                        print("Failed to load album tracks: \(error)")
                    }
                }
            }
        case .playlist:
            // Open playlist in-app instead of directly playing
            let playlistId = item.id
            print("🎵 Opening playlist in-app: \(item.title), PlaylistId: \(playlistId)")
            
            // Set selected playlist and load tracks
            searchState.selectedExplorePlaylist = item
            searchState.isLoadingExplorePlaylist = true
            searchState.selectedExplorePlaylistTracks = []
            
            Task {
                do {
                    let tracks = try await PythonServiceManager.shared.getPlaylistTracks(playlistId: playlistId)
                    print("🎵 Loaded \(tracks.count) tracks from playlist")
                    await MainActor.run {
                        searchState.selectedExplorePlaylistTracks = tracks
                        searchState.isLoadingExplorePlaylist = false
                    }
                } catch {
                    print("❌ Failed to load playlist tracks: \(error)")
                    await MainActor.run {
                        searchState.isLoadingExplorePlaylist = false
                    }
                }
            }
        case .artist:
            // Load artist songs
            if let browseId = item.browseId {
                Task {
                    do {
                        let tracks = try await PythonServiceManager.shared.getArtistSongs(browseId: browseId)
                        if let firstTrack = tracks.first {
                            let track = Track(from: firstTrack)
                            let allTracks = tracks.map { Track(from: $0) }
                            await searchState.playbackManager.play(track: track, fromQueue: allTracks)
                        }
                    } catch {
                        print("Failed to load artist songs: \(error)")
                    }
                }
            }
        }
    }
}

/// Loading placeholder for explore sections
struct ExploreSectionLoadingView: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.ultraThinMaterial)
                    .frame(width: 16, height: 16)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Loading placeholders
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
        }
    }
}

/// Mood/Genre category card
/// Moods & Genres Section with refresh button
struct MoodsAndGenresSection: View {
    let moodCategories: [String: [MoodCategory]]
    @ObservedObject var searchState: SearchState
    var isLoading: Bool = false
    var onRefresh: (() async -> Void)? = nil
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.purple)
                
                Text("Moods & Genres")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Refresh button
                if onRefresh != nil {
                    Button(action: {
                        guard !isRefreshing && !isLoading else { return }
                        isRefreshing = true
                        Task {
                            await onRefresh?()
                            await MainActor.run {
                                isRefreshing = false
                            }
                        }
                    }) {
                        ZStack {
                            if isRefreshing || isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh Moods & Genres")
                    .disabled(isRefreshing || isLoading)
                }
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(moodCategories.keys.sorted()), id: \.self) { category in
                        if let moods = moodCategories[category] {
                            ForEach(moods.prefix(8)) { mood in
                                MoodCategoryCard(
                                    mood: mood,
                                    searchState: searchState
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct MoodCategoryCard: View {
    let mood: MoodCategory
    @ObservedObject var searchState: SearchState
    @State private var isHovered = false
    @State private var isLoading = false
    
    // Gradient colors for different moods
    private var gradientColors: [Color] {
        let title = mood.title.lowercased()
        if title.contains("happy") || title.contains("party") {
            return [.yellow, .orange]
        } else if title.contains("sad") || title.contains("sleep") {
            return [.blue, .purple]
        } else if title.contains("romantic") || title.contains("love") {
            return [.pink, .red]
        } else if title.contains("chill") || title.contains("relax") {
            return [.teal, .blue]
        } else if title.contains("workout") || title.contains("energy") {
            return [.red, .orange]
        } else if title.contains("focus") || title.contains("study") {
            return [.green, .teal]
        } else if title.contains("bollywood") || title.contains("punjabi") {
            return [.orange, .red]
        } else if title.contains("rock") || title.contains("metal") {
            return [.gray, .black]
        } else if title.contains("hip") || title.contains("rap") {
            return [.purple, .black]
        } else if title.contains("edm") || title.contains("electronic") {
            return [.cyan, .purple]
        } else if title.contains("classical") || title.contains("devotional") {
            return [.orange, .yellow]
        } else {
            return [.blue, .purple]
        }
    }
    
    var body: some View {
        Button(action: {
            loadMoodPlaylist()
        }) {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Content
                VStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(mood.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(12)
            }
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: isHovered ? 8 : 4, x: 0, y: 2)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .disabled(isLoading)
    }
    
    private func loadMoodPlaylist() {
        isLoading = true
        
        Task {
            do {
                let songs = try await PythonServiceManager.shared.getMoodPlaylists(params: mood.params)
                
                await MainActor.run {
                    isLoading = false
                }
                
                if let firstSong = songs.first {
                    let track = Track(from: firstSong)
                    let tracks = songs.map { Track(from: $0) }
                    await searchState.playbackManager.play(track: track, fromQueue: tracks)
                }
            } catch {
                print("Failed to load mood playlist: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Explore Playlist Detail View

/// Shows tracks from a selected explore playlist
struct ExplorePlaylistDetailView: View {
    let playlist: SearchResult
    @ObservedObject var searchState: SearchState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    searchState.selectedExplorePlaylist = nil
                    searchState.selectedExplorePlaylistTracks = []
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Play all button
                if !searchState.selectedExplorePlaylistTracks.isEmpty {
                    Button(action: {
                        playAllTracks()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("Play All")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Playlist info header
            HStack(spacing: 16) {
                // Thumbnail
                AsyncImage(url: URL(string: playlist.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    
                    if let artist = playlist.artist {
                        Text(artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(searchState.selectedExplorePlaylistTracks.count) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 20)
            
            // Tracks list
            if searchState.isLoadingExplorePlaylist {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading tracks...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else if searchState.selectedExplorePlaylistTracks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No tracks found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchState.selectedExplorePlaylistTracks.enumerated()), id: \.element.id) { index, track in
                            ExplorePlaylistTrackRow(
                                track: track,
                                index: index + 1,
                                allTracks: searchState.selectedExplorePlaylistTracks,
                                searchState: searchState
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private func playAllTracks() {
        guard let firstTrack = searchState.selectedExplorePlaylistTracks.first else { return }
        let track = Track(from: firstTrack)
        let allTracks = searchState.selectedExplorePlaylistTracks.map { Track(from: $0) }
        Task {
            await searchState.playbackManager.play(track: track, fromQueue: allTracks)
        }
    }
}

/// Single track row in explore playlist detail view
struct ExplorePlaylistTrackRow: View {
    let track: SearchResult
    let index: Int
    let allTracks: [SearchResult]
    @ObservedObject var searchState: SearchState
    @State private var isHovered = false
    
    // Check if this track is currently playing
    private var isCurrentlyPlaying: Bool {
        guard let currentTrack = searchState.playbackManager.currentTrack,
              let trackVideoId = track.videoId,
              !trackVideoId.isEmpty else { return false }
        return currentTrack.videoId == trackVideoId
    }
    
    var body: some View {
        Button(action: {
            playTrack()
        }) {
            HStack(spacing: 12) {
                // Track number or playing indicator
                ZStack {
                    if isCurrentlyPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    } else {
                        Text("\(index)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 24)
                
                // Thumbnail
                AsyncImage(url: URL(string: track.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial)
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isCurrentlyPlaying ? .blue : .primary)
                        .lineLimit(1)
                    
                    if let artist = track.artist {
                        Text(artist)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Duration
                if let duration = track.duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Play indicator on hover
                if isHovered && !isCurrentlyPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCurrentlyPlaying ? Color.blue.opacity(0.15) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func playTrack() {
        let trackToPlay = Track(from: track)
        let queue = allTracks.map { Track(from: $0) }
        Task {
            await searchState.playbackManager.play(track: trackToPlay, fromQueue: queue)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
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