//
//  AppCoordinator.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import AppKit

class AppCoordinator: ObservableObject {
    private let searchState = SearchState()
    private let windowManager = WindowManager()
    private let hotkeyManager = GlobalHotkeyManager()
    private var appIsActive = false
    
    init() {
        setupCoordination()
        setupAppActivityObserver()
    }
    
    private func setupCoordination() {
        // Connect managers
        hotkeyManager.windowManager = windowManager
        windowManager.searchState = searchState
    }
    
    // 🔋 BATTERY EFFICIENCY: Save playback state when app becomes active
    private func setupAppActivityObserver() {
        // Observe when app becomes active
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppActivation()
        }
        
        // Observe when app resigns active
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppResignActive()
        }
    }
    
    func createSearchView() -> some View {
        // Return the music search view
        MusicSearchView(
            searchState: searchState,
            windowManager: windowManager
        )
        .frame(width: 600)
    }
    
    func setupWindow(_ window: NSWindow) {
        // Hide the main SwiftUI window since we use FloatingPanel instead
        window.orderOut(nil)
        windowManager.setupWindow(window)
    }
    
    func initializeApp() {
        // App is now fully initialized and ready to respond to hotkeys
        // The floating panel will be created when the hotkey is pressed
        print("🚀 Izzy app initialized - ready for hotkey (Option + Space)")
    }
    
    func handleAppActivation() {
        // 🔋 BATTERY EFFICIENCY: Save playback state when app becomes active
        // This ensures state is saved when user interacts with the app
        if !appIsActive {
            appIsActive = true
            searchState.playbackManager.savePlaybackState()
            print("💾 Saved playback state on app activation")
        }
        
        // Don't automatically show window on app activation
        // The window should only be shown via hotkey (Option + Space)
        // This prevents flickering when the app becomes active
    }
    
    func handleAppResignActive() {
        // 🔋 BATTERY EFFICIENCY: Save playback state when app resigns active
        appIsActive = false
        searchState.playbackManager.savePlaybackState()
        print("💾 Saved playback state on app resign active")
    }
    
    func handleAppTermination() {
        // Save playback state before app terminates
        searchState.playbackManager.savePlaybackState()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct SearchView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    
    var body: some View {
        VStack {
            SearchBar(
                searchState: searchState,
                windowManager: windowManager
            )
            .frame(width: 600, height: 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .allowsHitTesting(true)
    }
}