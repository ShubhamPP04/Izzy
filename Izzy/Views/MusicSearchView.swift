//
//  MusicSearchView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct MusicSearchView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    @State private var selectedTab = 0 // 0 = Search, 1 = Favorites, 2 = Recently Played, 3 = Settings
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack {
                Button(action: {
                    // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                    searchState.playbackManager.savePlaybackState()
                    selectedTab = 0
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .background(selectedTab == 0 ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                
                Button(action: {
                    // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                    searchState.playbackManager.savePlaybackState()
                    selectedTab = 1
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Favorites")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .background(selectedTab == 1 ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                
                Button(action: {
                    // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                    searchState.playbackManager.savePlaybackState()
                    selectedTab = 2
                }) {
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Recently Played")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .background(selectedTab == 2 ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                
                Button(action: {
                    // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                    searchState.playbackManager.savePlaybackState()
                    selectedTab = 3
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                .background(selectedTab == 3 ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Content based on selected tab
            if selectedTab == 0 {
                // Search Content
                VStack(spacing: 0) {
                    SearchBarView(
                        searchState: searchState,
                        windowManager: windowManager
                    )
                    
                    // Search Results
                    if searchState.showResults {
                        SearchResultsView(
                            musicSearchManager: searchState.musicSearchManager,
                            playbackManager: searchState.playbackManager,
                            windowManager: windowManager,
                            searchState: searchState
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .onAppear {
                            print("🎯 SearchResultsView appeared")
                        }
                    } else {
                        SearchStateIndicator(musicSearchManager: searchState.musicSearchManager)
                            .frame(maxHeight: 60)
                            .transition(.opacity)
                            .onAppear {
                                print("🎯 SearchStateIndicator appeared")
                            }
                    }
                }
            } else if selectedTab == 1 {
                // Favorites Content
                FavoritesView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 2 {
                // Recently Played Content
                RecentlyPlayedView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Settings Content
                SettingsView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Playback Controls (show when there's a current track OR when there's a playback error OR when buffering)
            if searchState.playbackManager.currentTrack != nil || 
               searchState.playbackManager.playbackState.isError ||
               searchState.playbackManager.playbackState == .buffering {
                CompactPlaybackControlsView(
                    playbackManager: searchState.playbackManager
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchState.showResults)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: searchState.playbackManager.currentTrack != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selectedTab)
        .onReceive(searchState.playbackManager.$currentTrack) { currentTrack in
            // Force UI update when currentTrack changes
            print("🎮 PlaybackManager currentTrack changed: \(currentTrack?.title ?? "nil")")
        }
    }
}

struct SearchBarView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search Icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            // Search TextField
            TextField("Search for music...", text: $searchState.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16, weight: .medium))
                .focused($isSearchFocused)
                .onSubmit {
                    searchState.executeSelectedResult()
                    // Keep window open to show playback controls
                }
                .onKeyPress { keyPress in
                    handleKeyPress(keyPress)
                }
                .onChange(of: searchState.searchText) { _, newValue in
                    print("🔤 Search text changed to: '\(newValue)'")
                }
            
            // Loading indicator or clear button
            if searchState.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !searchState.searchText.isEmpty {
                Button(action: {
                    searchState.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
        .onChange(of: windowManager.isVisible) { _, isVisible in
            if isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            } else {
                isSearchFocused = false
            }
        }
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .escape:
            if searchState.showResults {
                searchState.clearSearch()
            } else {
                windowManager.hideWindow()
            }
            return .handled
        case .upArrow:
            searchState.moveSelectionUp()
            return .handled
        case .downArrow:
            searchState.moveSelectionDown()
            return .handled
        default:
            return .ignored
        }
    }
}

#Preview {
    MusicSearchView(
        searchState: SearchState(),
        windowManager: WindowManager()
    )
    .frame(width: 600, height: 650)
    .background(Color.black.opacity(0.3))
}