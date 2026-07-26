//
//  MiniPlayerManager.swift
//  Izzy
//
//  Created by Assistant on 21/09/25.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Notification Names Extension
extension NSNotification.Name {
    static let miniPlayerClosed = NSNotification.Name("miniPlayerClosed")
}

// MARK: - Mini Player Manager
class MiniPlayerManager: ObservableObject {
    static let shared = MiniPlayerManager()
    
    private var miniPlayerWindow: NSWindow?
    private var windowDelegate: MiniPlayerWindowDelegate?
    private var searchState: SearchState?
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "miniPlayerEnabled")
            updateMiniPlayer()
        }
    }
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTrack: Track?
    
    // Window state properties
    @Published var windowFrame: NSRect = NSRect(x: 100, y: 100, width: 300, height: 120) {
        didSet {
            saveMiniPlayerFrame()
        }
    }
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "miniPlayerEnabled")
        loadMiniPlayerFrame()
        
        // Setup mini player on app start if enabled
        if isEnabled {
            DispatchQueue.main.async {
                self.updateMiniPlayer()
            }
        }
    }
    
    func configure(searchState: SearchState) {
        self.searchState = searchState
        
        // Update mini player if it should be enabled
        updateMiniPlayer()

        // Listen for track changes
        searchState.playbackManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (track: Track?) in
                self?.currentTrack = track
                self?.updateMiniPlayerContent()
            }
            .store(in: &cancellables)
        
        // Listen for playback state changes
        searchState.playbackManager.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: PlaybackState) in
                self?.playbackState = state
                self?.updateMiniPlayerContent()
            }
            .store(in: &cancellables)
        
        // Listen for duration changes
        searchState.playbackManager.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (duration: TimeInterval) in
                self?.duration = duration
            }
            .store(in: &cancellables)
        
        // Listen for time changes
        searchState.playbackManager.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (time: TimeInterval) in
                self?.currentTime = time
            }
            .store(in: &cancellables)
    }
    
    func updateMiniPlayer() {
        DispatchQueue.main.async { [weak self] in
            if self?.isEnabled == true {
                self?.showMiniPlayer()
            } else {
                self?.hideMiniPlayer()
            }
        }
    }
    
    private func showMiniPlayer() {
        guard searchState != nil else { return }
        
        if miniPlayerWindow == nil {
            // Create a custom floating window
            miniPlayerWindow = NSWindow(
                contentRect: windowFrame,
                styleMask: [.borderless, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            setupMiniPlayerContent()
            configureMiniPlayerWindow()
        }
        
        miniPlayerWindow?.makeKeyAndOrderFront(self)
        updateMiniPlayerContent()
    }
    
    private func hideMiniPlayer() {
        // Just hide the window, don't close it
        // Closing triggers app termination for accessory apps (no dock icon)
        if let window = miniPlayerWindow {
            window.orderOut(nil)
        }
        // Note: We keep miniPlayerWindow reference so it can be shown again quickly
    }
    
    private func setupMiniPlayerContent() {
        guard let searchState = searchState else { return }
        
        let contentView = MiniPlayerView(manager: self, searchState: searchState)
        miniPlayerWindow?.contentView = NSHostingView(rootView: contentView)
    }
    
    private func configureMiniPlayerWindow() {
        guard let window = miniPlayerWindow else { return }
        
        // Set window properties for liquid glass effect
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.level = NSWindow.Level.floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Set minimum and maximum sizes
        window.minSize = NSSize(width: 250, height: 100)
        window.maxSize = NSSize(width: 600, height: 300)
        
        // Enable drag and resize
        window.isMovableByWindowBackground = true
        
        // Retain the delegate. NSWindow.delegate is a weak reference, so assigning a
        // freshly constructed object let it deallocate on the spot — the delegate was
        // always nil and mini-player frame changes were never persisted.
        let delegate = MiniPlayerWindowDelegate(manager: self)
        windowDelegate = delegate
        window.delegate = delegate
    }
    
    private func updateMiniPlayerContent() {
        // The view will automatically update through @ObservedObject
    }
    
    // MARK: - Frame Persistence
    private func saveMiniPlayerFrame() {
        let frameDict = [
            "x": windowFrame.origin.x,
            "y": windowFrame.origin.y,
            "width": windowFrame.size.width,
            "height": windowFrame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: "miniPlayerFrame")
    }
    
    private func loadMiniPlayerFrame() {
        if let frameDict = UserDefaults.standard.dictionary(forKey: "miniPlayerFrame") {
            let x = frameDict["x"] as? CGFloat ?? 100
            let y = frameDict["y"] as? CGFloat ?? 100
            let width = frameDict["width"] as? CGFloat ?? 300
            let height = frameDict["height"] as? CGFloat ?? 120
            
            windowFrame = NSRect(x: x, y: y, width: width, height: height)
        }
    }
    
    func updateWindowFrame(_ frame: NSRect) {
        windowFrame = frame
    }
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Mini Player Window Delegate
class MiniPlayerWindowDelegate: NSObject, NSWindowDelegate {
    weak var manager: MiniPlayerManager?
    
    init(manager: MiniPlayerManager) {
        self.manager = manager
    }
    
    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            manager?.updateWindowFrame(window.frame)
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            manager?.updateWindowFrame(window.frame)
        }
    }
}