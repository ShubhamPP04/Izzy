//
//  SearchState.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import Combine

class SearchState: ObservableObject {
    @Published var searchText: String = "" {
        didSet {
            // Keep results panel open by default, only hide when explicitly cleared
            let hasText = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if hasText && !showResults {
                print("🚀 Showing results for text: '\(searchText)'")
                showResults = true
            }
        }
    }
    @Published var showResults: Bool = true
    
    // Music search integration
    let musicSearchManager = MusicSearchManager()
    let playbackManager = PlaybackManager.shared
    
    // Persistent state that survives window hide/show
    private var persistentSearchText: String = ""
    private var persistentResults: MusicSearchResults = MusicSearchResults()
    private var searchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var isRestoringState: Bool = false
    
    init() {
        setupSearchObserver()
        setupMusicSearchObserver()
    }
    
    deinit {
        searchCancellable?.cancel()
        cancellables.removeAll()
    }
    
    private func setupSearchObserver() {
        // Debounced search with 800ms delay - only search after user finishes typing
        searchCancellable = $searchText
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
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
        print("💾 Saved search state: '\(persistentSearchText)' with \(persistentResults.totalCount) results")
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