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
    @State private var selectedTab: Int
    
    init(searchState: SearchState, windowManager: WindowManager) {
        self.searchState = searchState
        self.windowManager = windowManager
        // Use the tab from SearchState which already handles startup logic
        _selectedTab = State(initialValue: searchState.persistentSelectedTab)
    }
    @AppStorage("iconOnlyNavigation") private var iconOnlyNavigation = false
    @AppStorage("startupTab") private var startupTab = 1
    @AppStorage("hasInitialized") private var hasInitialized = false
    @AppStorage("appHasBeenInitialized") private var appHasBeenInitialized = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector with horizontal scrolling
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button(action: {
                        // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                        searchState.playbackManager.savePlaybackState()
                        selectedTab = 0
                        print("📍 Switched to Home tab (0)")
                    }) {
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Home")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedTab == 0 ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    
                    Button(action: {
                        // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                        searchState.playbackManager.savePlaybackState()
                        selectedTab = 1
                        print("📍 Switched to Search tab (1)")
                    }) {
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Search")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
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
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Favorites")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
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
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Recently Played")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedTab == 3 ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    
                    Button(action: {
                        // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                        searchState.playbackManager.savePlaybackState()
                        selectedTab = 5
                    }) {
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Playlists")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedTab == 5 ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    
                    Button(action: {
                        // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                        searchState.playbackManager.savePlaybackState()
                        selectedTab = 6
                    }) {
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Up Next")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedTab == 6 ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                    
                    Button(action: {
                        // 🔋 BATTERY EFFICIENCY: Save playback state when switching tabs
                        searchState.playbackManager.savePlaybackState()
                        selectedTab = 4
                    }) {
                        HStack(spacing: iconOnlyNavigation ? 0 : 6) {
                            Image(systemName: "gear")
                                .font(.system(size: 14))
                            if !iconOnlyNavigation {
                                Text("Settings")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .padding(.horizontal, iconOnlyNavigation ? 12 : 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(selectedTab == 4 ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
            
            // Content based on selected tab
            if selectedTab == 0 {
                // Home Content
                HomeView(
                    searchState: searchState,
                    windowManager: windowManager,
                    selectedTab: $selectedTab
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 1 {
                // Search Content
                VStack(spacing: 0) {
                    SearchBarView(
                        searchState: searchState,
                        windowManager: windowManager,
                        selectedTab: selectedTab
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
            } else if selectedTab == 2 {
                // Favorites Content
                FavoritesView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 3 {
                // Recently Played Content
                RecentlyPlayedView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 5 {
                // Playlists Content
                PlaylistView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedTab == 6 {
                // Up Next Content
                UpNextView(searchState: searchState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Settings Content
                SettingsView(searchState: searchState, windowManager: windowManager)
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
        .modifier(MusicSearchViewBackgroundModifier())
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchState.showResults)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: searchState.playbackManager.currentTrack != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selectedTab)
        .onReceive(searchState.playbackManager.$currentTrack) { currentTrack in
            // Force UI update when currentTrack changes
            print("🎮 PlaybackManager currentTrack changed: \(currentTrack?.title ?? "nil")")
        }
        .onAppear {
            // Get the correct tab based on first launch or persistence
            let correctTab = searchState.getPersistedSelectedTab()
            if selectedTab != correctTab {
                selectedTab = correctTab
                print("🔄 Tab updated on appear: \(correctTab)")
            }
            print("🏠 MusicSearchView appeared - displaying tab \(selectedTab)")
        }
        .onChange(of: selectedTab) { _, newTab in
            // Save selected tab whenever it changes
            searchState.saveSelectedTab(newTab)
            print("💾 Tab changed to: \(newTab)")
        }
        .onKeyPress { keyPress in
            handleGlobalKeyPress(keyPress)
        }
    }
    
    private func handleGlobalKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .tab:
            // Cycle through tabs with Tab key
            let nextTab = (selectedTab + 1) % 6
            selectedTab = nextTab == 4 ? 0 : nextTab // Skip Settings (4) and wrap around
            print("🔄 Tab switched to: \(selectedTab)")
            return .handled
        case .escape:
            // Hide window on Escape
            windowManager.hideWindow()
            return .handled
        default:
            return .ignored
        }
    }
}

struct SearchBarView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    var selectedTab: Int
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
        .modifier(SearchBarBackgroundModifier())
        .onChange(of: windowManager.isVisible) { _, isVisible in
            if isVisible && selectedTab == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            } else if !isVisible {
                isSearchFocused = false
            }
        }
        .onAppear {
            // Focus search bar when Search tab is selected on appear
            if selectedTab == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isSearchFocused = true
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Focus search bar when switching to Search tab
            if newTab == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            } else {
                // Unfocus search bar when switching away from Search tab
                isSearchFocused = false
            }
            // Note: Tab persistence is now handled in MusicSearchView
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToUpNextTab"))) { _ in
            // Switch to Up Next tab when Up Next button is pressed in playback controls
            // Temporarily disabled due to SwiftUI state mutation issues
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

// Conditional background modifier for MusicSearchView
struct MusicSearchViewBackgroundModifier: ViewModifier {
    @ObservedObject private var liquidGlassSettings = LiquidGlassSettings.shared
    
    func body(content: Content) -> some View {
        if liquidGlassSettings.isEnabled {
            content
                .liquidGlassContainer(cornerRadius: 20)
                .liquidGlass(isInteractive: true, cornerRadius: 20, intensity: 0.25)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
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