//
//  MusicSearchManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation
import Combine

// MARK: - Search Manager

class MusicSearchManager: ObservableObject {
    @Published var searchResults: MusicSearchResults = MusicSearchResults()
    @Published var isSearching: Bool = false
    @Published var searchError: String?
    @Published var selectedResultIndex: Int = 0
    @Published var selectedCategory: SearchResultType = .song
    
    private let pythonService = PythonServiceManager.shared
    private var searchCancellable: AnyCancellable?
    private let searchDebouncer = Debouncer(delay: 0.3)
    
    // Cache for recent searches (3 minute timeout to avoid stale results)
    private var searchCache: [String: (results: MusicSearchResults, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 180 // 3 minutes
    
    init() {
        // Initialize Python service asynchronously to avoid blocking app startup
        Task {
            do {
                try await pythonService.ensureServiceRunning()
                print("✅ Music service initialized successfully")
            } catch {
                print("⚠️ Failed to start music service: \(error.localizedDescription)")
                await MainActor.run {
                    self.searchError = "Music service unavailable: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Search Methods
    
    func search(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearResults()
            return
        }
        
        // Use debouncer to avoid excessive API calls
        searchDebouncer.debounce { [weak self] in
            await self?.performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Get current music source to include in cache key
        let currentMusicSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        let cacheKey = "\(trimmedQuery)_\(currentMusicSource)"
        
        // Check cache first (now includes music source in key)
        if let cached = searchCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            await MainActor.run {
                self.searchResults = cached.results
                self.isSearching = false
                self.searchError = nil
                self.resetSelection()
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
            self.searchError = nil
        }
        
        do {
            let results = try await pythonService.searchMusic(query: query, limit: 20)
            
            print("🔍 Search completed for '\(query)' using '\(currentMusicSource)': \(results.songs.count) songs, \(results.albums.count) albums")
            
            // Log first few results for debugging
            for (index, song) in results.songs.prefix(3).enumerated() {
                print("🎵 Song \(index + 1): \(song.title) by \(song.artist ?? "Unknown") - VideoID: \(song.videoId ?? "None")")
            }
            
            // Cache the results with music source in key - only if we got actual results
            if !results.isEmpty {
                searchCache[cacheKey] = (results: results, timestamp: Date())
                cleanupOldCache()
            }
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
                self.resetSelection()
                // Track query and reset pagination for Tidal
                self.currentSearchQuery = query
                self.tidalSongOffset = 0
                self.tidalHasMoreSongs = currentMusicSource == "tidal" && results.songs.count >= 20
            }
            
        } catch {
            await MainActor.run {
                self.isSearching = false
                self.searchError = "Search failed: \(error.localizedDescription)"
                print("❌ Search error: \(error)")
                
                // Clear results on error to prevent showing stale data
                self.searchResults.clear()
            }
        }
    }
    
    private func cleanupOldCache() {
        let cutoffTime = Date().addingTimeInterval(-cacheTimeout)
        searchCache = searchCache.filter { $0.value.timestamp > cutoffTime }
    }
    
    func clearResults() {
        searchResults.clear()
        isSearching = false
        searchError = nil
        resetSelection()
    }
    
    // MARK: - Music Source Change Handling
    
    func clearCacheForMusicSourceChange() {
        // Clear all cached results when music source changes
        searchCache.removeAll()
        print("🗑️ Cleared search cache due to music source change")
    }
    
    // MARK: - Selection Management
    
    private func resetSelection() {
        selectedResultIndex = -1  // No selection by default
        selectedCategory = .song
    }
    
    func moveSelectionUp() {
        let currentResults = getCurrentCategoryResults()
        if selectedResultIndex == -1 {
            // No selection, select last item in current category
            selectedResultIndex = max(0, currentResults.count - 1)
        } else if selectedResultIndex > 0 {
            selectedResultIndex -= 1
        } else {
            // Move to previous category
            moveToPreviousCategory()
        }
    }
    
    func moveSelectionDown() {
        let currentResults = getCurrentCategoryResults()
        if selectedResultIndex == -1 {
            // No selection, select first item in current category
            selectedResultIndex = currentResults.isEmpty ? -1 : 0
        } else if selectedResultIndex < currentResults.count - 1 {
            selectedResultIndex += 1
        } else {
            // Move to next category
            moveToNextCategory()
        }
    }
    
    private func moveToPreviousCategory() {
        let categories = SearchResultType.allCases
        guard let currentIndex = categories.firstIndex(of: selectedCategory) else { return }
        
        var newIndex = currentIndex - 1
        while newIndex >= 0 {
            let category = categories[newIndex]
            let results = searchResults.results(for: category)
            if !results.isEmpty {
                selectedCategory = category
                selectedResultIndex = results.count - 1
                return
            }
            newIndex -= 1
        }
    }
    
    private func moveToNextCategory() {
        let categories = SearchResultType.allCases
        guard let currentIndex = categories.firstIndex(of: selectedCategory) else { return }
        
        var newIndex = currentIndex + 1
        while newIndex < categories.count {
            let category = categories[newIndex]
            let results = searchResults.results(for: category)
            if !results.isEmpty {
                selectedCategory = category
                selectedResultIndex = 0
                return
            }
            newIndex += 1
        }
    }
    
    func getCurrentCategoryResults() -> [SearchResult] {
        return searchResults.results(for: selectedCategory)
    }
    
    func getSelectedResult() -> SearchResult? {
        let results = getCurrentCategoryResults()
        guard selectedResultIndex >= 0 && selectedResultIndex < results.count else { return nil }
        return results[selectedResultIndex]
    }
    
    // MARK: - Category Selection
    
    func selectCategory(_ category: SearchResultType) {
        let results = searchResults.results(for: category)
        guard !results.isEmpty else { return }
        
        selectedCategory = category
        selectedResultIndex = -1  // No selection by default
    }
    
    // MARK: - Result Actions
    
    func executeSelectedResult() -> SearchResult? {
        return getSelectedResult()
    }
    
    func getResultsForDisplay() -> [(category: SearchResultType, results: [SearchResult])] {
        return SearchResultType.allCases.compactMap { category in
            let results = searchResults.results(for: category)
            return results.isEmpty ? nil : (category: category, results: results)
        }
    }
    
    // MARK: - Additional Data Loading
    
    func loadAlbumTracks(browseId: String) async throws -> [SearchResult] {
        return try await pythonService.getAlbumTracks(browseId: browseId)
    }
    
    func loadPlaylistTracks(playlistId: String) async throws -> [SearchResult] {
        return try await pythonService.getPlaylistTracks(playlistId: playlistId)
    }
    
    func loadArtistSongs(browseId: String) async throws -> [SearchResult] {
        return try await pythonService.getArtistSongs(browseId: browseId)
    }
    
    /// Load more artist songs with pagination (for Tidal)
    func loadMoreArtistSongs(browseId: String, offset: Int) async throws -> [SearchResult] {
        return try await pythonService.getArtistSongsWithOffset(browseId: browseId, offset: offset, limit: 20)
    }
    
    // MARK: - Tidal Load More Songs
    
    /// Current search query for loading more results (Tidal only)
    private(set) var currentSearchQuery: String = ""
    
    /// Whether Tidal has more songs to load
    @Published var tidalHasMoreSongs: Bool = false
    
    /// Current offset for Tidal song pagination
    private var tidalSongOffset: Int = 0
    
    /// Load more Tidal songs (appends to existing results)
    func loadMoreTidalSongs() async {
        let currentMusicSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        guard currentMusicSource == "tidal", !currentSearchQuery.isEmpty else { return }
        
        do {
            let response = try await pythonService.loadMoreTidalSongs(
                query: currentSearchQuery,
                offset: tidalSongOffset + 20,
                limit: 20
            )
            
            await MainActor.run {
                // Get existing song IDs to avoid duplicates
                let existingIds = Set(self.searchResults.songs.compactMap { $0.videoId })
                
                // Filter out duplicates before appending
                let newSongs = response.songs.filter { song in
                    guard let videoId = song.videoId else { return true }
                    return !existingIds.contains(videoId)
                }
                
                self.searchResults.songs.append(contentsOf: newSongs)
                self.tidalHasMoreSongs = response.hasMore && !newSongs.isEmpty
                self.tidalSongOffset += 20
                
                print("📥 Loaded \(newSongs.count) new songs (filtered \(response.songs.count - newSongs.count) duplicates, total: \(self.searchResults.songs.count))")
            }
        } catch {
            print("❌ Failed to load more Tidal songs: \(error)")
        }
    }
}

// MARK: - Debouncer Utility

class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () async -> Void) {
        workItem?.cancel()
        
        workItem = DispatchWorkItem {
            Task {
                await action()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}

// MARK: - Extensions

extension MusicSearchResults {
    var hasResults: Bool {
        return !isEmpty
    }
    
    var categoriesWithResults: [SearchResultType] {
        return SearchResultType.allCases.filter { !results(for: $0).isEmpty }
    }
}