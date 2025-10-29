//
//  MusicSearchManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation
import Combine

// MARK: - LRU Cache Implementation

/// 🚀 PERFORMANCE: LRU Cache with automatic eviction for memory efficiency
/// Uses OrderedDictionary-like approach for O(1) access
class LRUCache<Key: Hashable, Value> {
    private struct CacheEntry {
        let value: Value
        let timestamp: Date
    }
    
    private var cache: [Key: CacheEntry] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    private let timeout: TimeInterval
    
    init(maxSize: Int = 50, timeout: TimeInterval = 600) {
        self.maxSize = maxSize
        self.timeout = timeout
        // Pre-allocate arrays to avoid reallocation
        self.accessOrder.reserveCapacity(maxSize)
    }
    
    func get(_ key: Key) -> Value? {
        guard let entry = cache[key] else { return nil }
        
        // Check if entry has expired
        if Date().timeIntervalSince(entry.timestamp) > timeout {
            remove(key)
            return nil
        }
        
        // 🚀 OPTIMIZED: Move to end efficiently
        updateAccessOrder(for: key)
        
        return entry.value
    }
    
    func set(_ key: Key, value: Value) {
        // If cache is full and key is new, remove LRU item
        if cache.count >= maxSize && cache[key] == nil {
            if let lruKey = accessOrder.first {
                remove(lruKey)
            }
        }
        
        cache[key] = CacheEntry(value: value, timestamp: Date())
        updateAccessOrder(for: key)
    }
    
    private func updateAccessOrder(for key: Key) {
        // 🚀 OPTIMIZED: Use last index search (typically faster for LRU)
        // Most recently accessed items are at the end
        if let index = accessOrder.lastIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
    }
    
    func remove(_ key: Key) {
        cache.removeValue(forKey: key)
        // 🚀 OPTIMIZED: Search from end where most recent items are
        if let index = accessOrder.lastIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }
    
    func removeAll() {
        cache.removeAll(keepingCapacity: true)
        accessOrder.removeAll(keepingCapacity: true)
    }
    
    /// 🚀 OPTIMIZED: Batch cleanup for better performance
    func cleanup() {
        let now = Date()
        var keysToRemove: [Key] = []
        
        // Collect expired keys first
        for (key, entry) in cache {
            if now.timeIntervalSince(entry.timestamp) > timeout {
                keysToRemove.append(key)
            }
        }
        
        // Batch remove for better performance
        keysToRemove.forEach { remove($0) }
    }
}

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
    
    // 🚀 PERFORMANCE: LRU Cache for efficient memory management
    private let searchCache = LRUCache<String, MusicSearchResults>(maxSize: 50, timeout: 600)
    
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
        
        // 🚀 PERFORMANCE: Check LRU cache first
        if let cached = searchCache.get(cacheKey) {
            await MainActor.run {
                self.searchResults = cached
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
            
            // 🚀 PERFORMANCE: Cache the results with LRU eviction
            searchCache.set(cacheKey, value: results)
            
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
                self.resetSelection()
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
    
    func clearResults() {
        searchResults.clear()
        isSearching = false
        searchError = nil
        resetSelection()
    }
    
    // MARK: - Music Source Change Handling
    
    func clearCacheForMusicSourceChange() {
        // 🚀 PERFORMANCE: Clear LRU cache when music source changes
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