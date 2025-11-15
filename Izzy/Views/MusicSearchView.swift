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
    @State private var isSearchBarFocused: Bool = false
    @State private var isAISearchPromptFocused: Bool = false
    
    // Scroll position tracking for each tab using CGFloat values
    @State private var homeScrollOffset: CGFloat = 0
    @State private var searchScrollOffset: CGFloat = 0
    @State private var aiSearchScrollOffset: CGFloat = 0
    @State private var favoritesScrollOffset: CGFloat = 0
    @State private var recentlyPlayedScrollOffset: CGFloat = 0
    @State private var upNextScrollOffset: CGFloat = 0
    @State private var playlistsScrollOffset: CGFloat = 0
    @State private var settingsScrollOffset: CGFloat = 0
    
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
    @AppStorage("showAISearch") private var showAISearch = true
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Animated Tab Navigation
                AnimatedTabNavigation(
                    selectedTab: $selectedTab,
                    showAISearch: showAISearch,
                    onTabChange: { newTab in
                        searchState.playbackManager.savePlaybackState()
                        selectedTab = newTab
                        print("📍 Switched to tab \(newTab)")
                    }
                )
                .overlay(
                    // Drag Handle overlaid on top of the navigation
                    DragHandleView()
                        .frame(height: 24),
                    alignment: .top
                )
            
            // Content based on selected tab - Using opacity-based switching to preserve scroll positions
            ZStack {
                // Home Content
                HomeView(
                    searchState: searchState,
                    windowManager: windowManager,
                    selectedTab: $selectedTab,
                    scrollOffset: $homeScrollOffset
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedTab == 0 ? 1 : 0)
                
                // Search Content
                VStack(spacing: 0) {
                    SearchBarView(
                        searchState: searchState,
                        windowManager: windowManager,
                        selectedTab: selectedTab,
                        isSearchBarFocused: $isSearchBarFocused
                    )
                    
                    // Search Results
                    if searchState.showResults {
                        SearchResultsView(
                            musicSearchManager: searchState.musicSearchManager,
                            playbackManager: searchState.playbackManager,
                            windowManager: windowManager,
                            searchState: searchState,
                            scrollOffset: $searchScrollOffset
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
                .opacity(selectedTab == 1 ? 1 : 0)

                if showAISearch {
                    AISearchView(
                        searchState: searchState,
                        windowManager: windowManager,
                        selectedTab: $selectedTab,
                        scrollOffset: $aiSearchScrollOffset,
                        isPromptFocused: $isAISearchPromptFocused
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 7 ? 1 : 0)
                }
                
                // Favorites Content
                FavoritesView(searchState: searchState, scrollOffset: $favoritesScrollOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 2 ? 1 : 0)
                
                // Recently Played Content
                RecentlyPlayedView(searchState: searchState, scrollOffset: $recentlyPlayedScrollOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 3 ? 1 : 0)
                
                // Playlists Content
                PlaylistView(searchState: searchState, scrollOffset: $playlistsScrollOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 5 ? 1 : 0)
                
                // Up Next Content
                UpNextView(searchState: searchState, scrollOffset: $upNextScrollOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 6 ? 1 : 0)
                
                // Settings Content
                SettingsView(searchState: searchState, windowManager: windowManager, scrollOffset: $settingsScrollOffset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 4 ? 1 : 0)
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
        
        // Quit Button - Top Right Corner
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 20, height: 20)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Quit Izzy")
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
            Spacer()
        }
    }
        .modifier(MusicSearchViewBackgroundModifier())
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: searchState.showResults)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: searchState.playbackManager.currentTrack != nil)
        // Removed selectedTab animation to prevent view recreation and maintain scroll positions
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
            if newTab != 7 {
                isAISearchPromptFocused = false
            }
        }
        .onKeyPress { keyPress in
            handleGlobalKeyPress(keyPress)
        }
        // Removed scroll position save/restore notifications to allow natural persistence
    }
    
    // MARK: - Scroll Position Persistence
    // Removed UserDefaults scroll position save/restore to allow natural persistence
    
    private var keyboardTabSequence: [Int] {
        AnimatedTabNavigation.keyboardNavigableTags(showAISearch: showAISearch)
    }
    
    private func handleGlobalKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // Don't handle keyboard shortcuts if search bar is focused
        if isSearchBarFocused || isAISearchPromptFocused {
            print("🔍 Ignoring keyboard shortcut - search bar is focused")
            return .ignored
        }
        
        switch keyPress.key {
        case .space:
            // Handle play/pause with spacebar
            handlePlayPauseToggle()
            return .handled
        case .leftArrow:
            // Seek backward 10 seconds with left arrow
            handleSeekBackward()
            return .handled
        case .rightArrow:
            // Seek forward 10 seconds with right arrow
            handleSeekForward()
            return .handled
        case .tab:
            if let currentIndex = keyboardTabSequence.firstIndex(of: selectedTab) {
                let nextIndex = (currentIndex + 1) % keyboardTabSequence.count
                selectedTab = keyboardTabSequence[nextIndex]
            } else if let fallback = keyboardTabSequence.first {
                selectedTab = fallback
            }
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
    
    // MARK: - Playback Keyboard Shortcuts
    
    private func handlePlayPauseToggle() {
        let playbackManager = searchState.playbackManager
        switch playbackManager.playbackState {
        case .playing:
            playbackManager.pause()
            print("🎵 SwiftUI Keyboard shortcut: Paused")
        case .paused:
            playbackManager.resume()
            print("🎵 SwiftUI Keyboard shortcut: Resumed")
        case .stopped:
            // If stopped, try to resume from saved position or start current track
            if playbackManager.currentTrack != nil {
                Task {
                    await playbackManager.resumeFromSavedPosition()
                    print("🎵 SwiftUI Keyboard shortcut: Resumed from saved position")
                }
            }
        case .buffering:
            // For buffering state, try to pause/resume anyway
            playbackManager.pause()
            print("🎵 SwiftUI Keyboard shortcut: Paused (was buffering)")
        case .error:
            // For error state, try to resume from saved position
            if playbackManager.currentTrack != nil {
                Task {
                    await playbackManager.resumeFromSavedPosition()
                    print("🎵 SwiftUI Keyboard shortcut: Resumed from error state")
                }
            }
        }
    }
    
    private func handleSeekBackward() {
        let playbackManager = searchState.playbackManager
        let newTime = max(0, playbackManager.currentTime - 10.0) // Seek back 10 seconds
        playbackManager.seek(to: newTime)
        print("🎵 SwiftUI Keyboard shortcut: Seeked backward to \(Int(newTime))s")
    }
    
    private func handleSeekForward() {
        let playbackManager = searchState.playbackManager
        let newTime = min(playbackManager.duration, playbackManager.currentTime + 10.0) // Seek forward 10 seconds
        playbackManager.seek(to: newTime)
        print("🎵 SwiftUI Keyboard shortcut: Seeked forward to \(Int(newTime))s")
    }
}

struct SearchBarView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    var selectedTab: Int
    @Binding var isSearchBarFocused: Bool
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
                // Sync focus state with binding
                .onChange(of: isSearchFocused) { _, newValue in
                    isSearchBarFocused = newValue
                    print("🔍 Search bar focus changed: \(newValue)")
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

// MARK: - Animated Tab Navigation Component
struct AnimatedTabNavigation: View {
    struct TabItem: Identifiable {
        let icon: String
        let title: String
        let tag: Int
        var id: Int { tag }
    }
    
    static let tabItems: [TabItem] = [
        TabItem(icon: "house.fill", title: "Home", tag: 0),
        TabItem(icon: "magnifyingglass", title: "Search", tag: 1),
        TabItem(icon: "sparkle.magnifyingglass", title: "AI Search", tag: 7),
        TabItem(icon: "heart.fill", title: "Favorites", tag: 2),
        TabItem(icon: "clock.fill", title: "Recently Played", tag: 3),
        TabItem(icon: "music.note.list", title: "Playlists", tag: 5),
        TabItem(icon: "list.bullet", title: "Up Next", tag: 6),
        TabItem(icon: "gear", title: "Settings", tag: 4)
    ]
    
    static func keyboardNavigableTags(showAISearch: Bool) -> [Int] {
        tabItems
            .map(\.tag)
            .filter { $0 != 4 && (showAISearch || $0 != 7) }
    }
    
    @Binding var selectedTab: Int
    let showAISearch: Bool
    let onTabChange: (Int) -> Void
    
    private var tabs: [TabItem] {
        AnimatedTabNavigation.tabItems.filter { showAISearch || $0.tag != 7 }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                AnimatedTabButton(
                    icon: tab.icon,
                    title: tab.title,
                    isSelected: selectedTab == tab.tag,
                    action: { onTabChange(tab.tag) }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct AnimatedTabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if isHovered {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
            }
            .padding(.horizontal, isHovered ? 16 : 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
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