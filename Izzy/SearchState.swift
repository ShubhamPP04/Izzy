//
//  SearchState.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import Combine
import Foundation

class SearchState: ObservableObject {
    @Published var searchText: String = "" {
        didSet {
            // 🔋 BATTERY EFFICIENCY: Save playback state when user interacts with search
            playbackManager.savePlaybackState()
            
            // Keep results panel open by default, only hide when explicitly cleared
            let hasText = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasText && !showResults {
                print("🚀 Showing results for text: '\(searchText)'")
                showResults = true
            }
        }
    }
    @Published var showResults: Bool = true
    @Published var favorites: [FavoriteSong] = []
    @Published var recentlyPlayed: [FavoriteSong] = [] // Add this line for recently played songs
    
    // Music search integration
    let musicSearchManager = MusicSearchManager()
    let playbackManager = PlaybackManager.shared
    
    // Persistent state that survives window hide/show
    private var persistentSearchText: String = ""
    private var persistentResults: MusicSearchResults = MusicSearchResults()
    private var persistentSelectedTab: Int = 1 // Default to Search tab
    private var searchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var isRestoringState: Bool = false
    
    private let favoritesKey = "IzzyFavorites"
    private let recentlyPlayedKey = "IzzyRecentlyPlayed" // Add this line for persistence
    
    init() {
        setupSearchObserver()
        setupMusicSearchObserver()
        setupPlaybackObserver() // Add this line to observe playback changes
        loadFavorites()
        loadRecentlyPlayed() // Add this line to load recently played songs
    }
    
    deinit {
        searchCancellable?.cancel()
        cancellables.removeAll()
    }
    
    // Add this function to observe playback changes
    private func setupPlaybackObserver() {
        // Subscribe to playback manager updates
        playbackManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                if let track = track {
                    self?.addRecentlyPlayed(track)
                }
            }
            .store(in: &cancellables)
    }
    
    // Add this function to add songs to recently played
    func addRecentlyPlayed(_ track: Track) {
        // Get the current music source
        let currentMusicSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        // Convert Track to FavoriteSong
        let searchResult = SearchResult(
            id: track.id,
            type: .song,
            title: track.title,
            artist: track.artist,
            thumbnailURL: track.thumbnailURL,
            duration: track.duration,
            explicit: false,
            videoId: track.videoId,
            browseId: nil,
            year: track.year,
            playCount: nil
        )
        
        let favoriteSong = FavoriteSong(from: searchResult, musicSource: currentMusicSource)
        
        // Remove if already exists
        recentlyPlayed.removeAll { $0.videoId == favoriteSong.videoId }
        
        // Add to beginning of list (most recent first)
        recentlyPlayed.insert(favoriteSong, at: 0)
        
        // Limit to 50 recently played songs
        if recentlyPlayed.count > 50 {
            recentlyPlayed.removeLast()
        }
        
        // Save to persistence
        saveRecentlyPlayed()
    }
    
    // MARK: - Favorites Management
    
    func addFavorite(_ searchResult: SearchResult) {
        // Check if already favorited
        if isFavorited(searchResult) {
            return
        }
        
        // Get the current music source
        let currentMusicSource = UserDefaults.standard.string(forKey: "musicSource") ?? "youtube_music"
        
        let favoriteSong = FavoriteSong(from: searchResult, musicSource: currentMusicSource)
        favorites.insert(favoriteSong, at: 0) // Add to beginning of list
        saveFavorites()
    }
    
    func removeFavorite(_ searchResult: SearchResult) {
        favorites.removeAll { $0.videoId == searchResult.videoId }
        saveFavorites()
    }

    // Add this method to remove recently played songs
    func removeRecentlyPlayed(_ recentlyPlayed: FavoriteSong) {
        self.recentlyPlayed.removeAll { $0.videoId == recentlyPlayed.videoId }
        saveRecentlyPlayed()
    }

    func toggleFavorite(_ searchResult: SearchResult) {
        if isFavorited(searchResult) {
            removeFavorite(searchResult)
        } else {
            addFavorite(searchResult)
        }
    }
    
    func isFavorited(_ searchResult: SearchResult) -> Bool {
        return favorites.contains { $0.videoId == searchResult.videoId }
    }
    
    func reorderFavorites(from sourceIndex: Int, to destinationIndex: Int) {
        // Make sure indices are valid
        guard sourceIndex < favorites.count && destinationIndex < favorites.count else { return }
        guard sourceIndex != destinationIndex else { return }
        
        // Move the favorite
        let movedFavorite = favorites.remove(at: sourceIndex)
        favorites.insert(movedFavorite, at: destinationIndex)
        saveFavorites()
    }
    
    func updateFavoritesOrder(_ newOrder: [FavoriteSong]) {
        favorites = newOrder
        saveFavorites()
    }
    
    // Add similar functions for recently played songs
    func reorderRecentlyPlayed(from sourceIndex: Int, to destinationIndex: Int) {
        // Make sure indices are valid
        guard sourceIndex < recentlyPlayed.count && destinationIndex < recentlyPlayed.count else { return }
        guard sourceIndex != destinationIndex else { return }
        
        // Move the recently played song
        let movedSong = recentlyPlayed.remove(at: sourceIndex)
        recentlyPlayed.insert(movedSong, at: destinationIndex)
        saveRecentlyPlayed()
    }
    
    func updateRecentlyPlayedOrder(_ newOrder: [FavoriteSong]) {
        recentlyPlayed = newOrder
        saveRecentlyPlayed()
    }
    
    // MARK: - Persistence
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favorites)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            print("❌ Failed to save favorites: \(error)")
        }
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey) else { return }
        
        do {
            favorites = try JSONDecoder().decode([FavoriteSong].self, from: data)
        } catch {
            print("❌ Failed to load favorites: \(error)")
            favorites = []
        }
    }
    
    // Change this function from private to public
    func saveRecentlyPlayed() {
        do {
            let data = try JSONEncoder().encode(recentlyPlayed)
            UserDefaults.standard.set(data, forKey: recentlyPlayedKey)
        } catch {
            print("❌ Failed to save recently played: \(error)")
        }
    }
    
    // Add this function to load recently played songs
    private func loadRecentlyPlayed() {
        guard let data = UserDefaults.standard.data(forKey: recentlyPlayedKey) else { return }
        
        do {
            recentlyPlayed = try JSONDecoder().decode([FavoriteSong].self, from: data)
        } catch {
            print("❌ Failed to load recently played: \(error)")
            recentlyPlayed = []
        }
    }
    
    private func setupSearchObserver() {
        // Debounced search with 2 second delay - only search after user finishes typing
        searchCancellable = $searchText
            .debounce(for: .milliseconds(2000), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                // 🔋 BATTERY EFFICIENCY: Save playback state before performing search
                self?.playbackManager.savePlaybackState()
                
                // Don't trigger search if we're restoring state
                guard let self = self, !self.isRestoringState else { return }
                self.performSearch(searchText)
            }
    }
    
    private func setupMusicSearchObserver() {
        // Subscribe to music search manager updates
        musicSearchManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Show/hide results based on search state and searching status
        Publishers.CombineLatest4(
            musicSearchManager.$searchResults,
            musicSearchManager.$isSearching,
            musicSearchManager.$searchError,
            $searchText
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] results, isSearching, searchError, searchText in
            // Keep results panel open when we have search text or results
            let hasSearchText = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasResults = !results.isEmpty
            
            if (hasSearchText || hasResults) && self?.showResults == false {
                print("🔄 Auto-showing results: hasText=\(hasSearchText), hasResults=\(hasResults)")
                self?.showResults = true
            }
        }
        .store(in: &cancellables)
    }
    
    func saveState() {
        persistentSearchText = searchText
        persistentResults = musicSearchManager.searchResults
        // Note: persistentSelectedTab will be saved from MusicSearchView directly
        print("💾 Saved search state: '\(persistentSearchText)' with \(persistentResults.totalCount) results")
    }
    
    func saveSelectedTab(_ tabIndex: Int) {
        persistentSelectedTab = tabIndex
        print("💾 Saved selected tab: \(tabIndex)")
    }
    
    func getPersistedSelectedTab() -> Int {
        return persistentSelectedTab
    }
    
    func restoreState() {
        print("🔄 Restoring state - text: '\(persistentSearchText)', results: \(persistentResults.totalCount)")
        
        // Set flag to prevent search observer from triggering
        isRestoringState = true
        
        // First restore the results without triggering search
        if !persistentResults.isEmpty {
            musicSearchManager.searchResults = persistentResults
            showResults = true
            print("🔄 Restored \(persistentResults.totalCount) search results")
        }
        
        // Then restore search text without triggering search
        if !persistentSearchText.isEmpty {
            searchText = persistentSearchText
            showResults = true
            print("🔄 Restored search text: '\(persistentSearchText)'")
        }
        
        // Clear the flag after a short delay to allow normal search behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isRestoringState = false
        }
    }
    
    func clearSearch() {
        searchText = ""
        persistentSearchText = ""
        persistentResults = MusicSearchResults()
        // Keep showResults = true to prevent window collapse
        showResults = true
        musicSearchManager.clearResults()
        print("🧹 Cleared search state completely")
    }
    
    private func performSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            // Don't clear results if we're restoring state or if we have persistent results
            if !isRestoringState && persistentResults.isEmpty {
                musicSearchManager.clearResults()
            }
            return
        }
        
        print("🔍 Performing search for: '\(trimmedQuery)'")
        
        // Perform music search
        musicSearchManager.search(query: query)
    }
    
    func moveSelectionUp() {
        musicSearchManager.moveSelectionUp()
    }
    
    func moveSelectionDown() {
        musicSearchManager.moveSelectionDown()
    }
    
    func executeSelectedResult() {
        guard let selectedResult = musicSearchManager.executeSelectedResult() else {
            print("❌ No selected result to execute")
            return
        }
        
        print("🎵 Executing selected result: \(selectedResult.title) by \(selectedResult.artist ?? "Unknown")")
        print("🎵 Video ID: \(selectedResult.videoId ?? "No video ID")")
        
        Task {
            let track = Track(from: selectedResult)
            
            // Create queue from current search results
            let songsResults = musicSearchManager.searchResults.songs
            let allTracks = songsResults.map { Track(from: $0) }
            
            print("🎵 Starting playback for track: \(track.title)")
            print("🎵 Queue size: \(allTracks.count)")
            
            // Play the selected track with the full queue
            await playbackManager.play(track: track, fromQueue: allTracks)
            
            print("🎵 Playback initiated")
        }
    }
    
    // MARK: - Computed Properties
    
    var isSearching: Bool {
        return musicSearchManager.isSearching
    }
    
    var hasResults: Bool {
        return musicSearchManager.searchResults.hasResults
    }
    
    var searchError: String? {
        return musicSearchManager.searchError
    }
}