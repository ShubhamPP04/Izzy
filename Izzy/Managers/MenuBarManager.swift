//
//  MenuBarManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 11/09/25.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Simple Menu Bar Manager
class SimpleMenuBarManager: ObservableObject {
    static let shared = SimpleMenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var searchState: SearchState?
    private var windowManager: WindowManager?
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    
    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "menuBarPlayerEnabled")
            updateMenuBar()
        }
    }
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTrack: Track?
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "menuBarPlayerEnabled")
        // Automatically setup menu bar on app start if enabled
        if isEnabled {
            DispatchQueue.main.async {
                self.updateMenuBar()
            }
        }
    }
    
    func configure(searchState: SearchState, windowManager: WindowManager) {
        self.searchState = searchState
        self.windowManager = windowManager
        updateMenuBar()
        
        // Listen for track changes
        searchState.playbackManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (track: Track?) in
                self?.currentTrack = track
                self?.updateMenuBarContent()
            }
            .store(in: &cancellables)
        
        // Listen for playback state changes
        searchState.playbackManager.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: PlaybackState) in
                self?.playbackState = state
                self?.updateMenuBarContent()
                self?.updateProgressTimer()
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
    
    private func updateProgressTimer() {
        progressTimer?.invalidate()
        
        if playbackState.isPlaying {
            // Update progress every 100ms for smooth updates
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateProgressFromPlaybackManager()
            }
        }
    }
    
    private func updateProgressFromPlaybackManager() {
        guard let searchState = searchState else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentTime = searchState.playbackManager.currentTime
            self?.duration = searchState.playbackManager.duration
        }
    }
    
    // Changed from private to internal to allow access from AppCoordinator
    func updateMenuBar() {
        DispatchQueue.main.async { [weak self] in
            if self?.isEnabled == true {
                self?.setupMenuBar()
            } else {
                self?.removeMenuBar()
            }
        }
    }
    
    private func setupMenuBar() {
        guard searchState != nil, windowManager != nil else { return }
        
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.button?.image = createMenuBarIcon()
            statusItem?.button?.action = #selector(statusItemClicked)
            statusItem?.button?.target = self
            
            setupPopover()
        }
    }
    
    // Helper function to create menu bar icon from app assets
    private func createMenuBarIcon() -> NSImage? {
        // Try to load the app icon from assets
        if let appIcon = NSImage(named: "AppIcon") {
            // Resize the image to fit menu bar (typically 18x18)
            let resizedImage = resizeImage(appIcon, to: NSSize(width: 18, height: 18))
            resizedImage.isTemplate = false // Keep original colors for custom icon
            return resizedImage
        }
        
        // Fallback to system symbol if app icon not found
        return NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music Player")
    }
    
    // Helper function to resize NSImage
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    private func removeMenuBar() {
        progressTimer?.invalidate()
        progressTimer = nil
        
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
        popover?.performClose(nil)
        popover = nil
    }
    
    private func setupPopover() {
        guard let searchState = searchState else { return }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 140)
        popover?.behavior = .transient
        
        let contentView = SimpleMenuBarView(manager: self, searchState: searchState) { [weak self] in
            self?.popover?.performClose(nil)
        }
        
        popover?.contentViewController = NSHostingController(rootView: contentView)
    }
    
    @objc private func statusItemClicked() {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
    }
    
    private func updateMenuBarContent() {
        // Update status item icon based on playback state
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusItem?.button else { return }
            
            if self?.currentTrack != nil && self?.playbackState.isPlaying == true {
                // Use custom icon for playing state
                button.image = self?.createMenuBarIcon() ?? NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Now Playing")
            } else {
                // Use custom icon for idle state
                button.image = self?.createMenuBarIcon() ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music Player")
            }
        }
    }
    
    deinit {
        progressTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Simple Menu Bar View
struct SimpleMenuBarView: View {
    @ObservedObject var manager: SimpleMenuBarManager
    let searchState: SearchState
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Album artwork
            AsyncImage(url: URL(string: manager.currentTrack?.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Track info and controls
            VStack(alignment: .leading, spacing: 8) {
                // Track title and artist
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.currentTrack?.title ?? "No track playing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(manager.currentTrack?.artist ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                // Controls row
                HStack(spacing: 16) {
                    // Previous button
                    Button(action: { 
                        Task {
                            await searchState.playbackManager.playPrevious()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!searchState.playbackManager.queue.hasPrevious)
                    
                    // Play/Pause button
                    Button(action: { 
                        if manager.playbackState.isPlaying {
                            searchState.playbackManager.pause()
                        } else {
                            if searchState.playbackManager.currentTrack != nil {
                                searchState.playbackManager.resume()
                            } else {
                                // If no track, don't do anything or show a message
                                print("No track to play")
                            }
                        }
                    }) {
                        Image(systemName: manager.playbackState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Next button
                    Button(action: { 
                        Task {
                            await searchState.playbackManager.playNext()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!searchState.playbackManager.queue.hasNext)
                    
                    Spacer()
                }
                
                // Progress bar with time labels
                VStack(spacing: 4) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 4)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: progressWidth(geometry.size.width), height: 4)
                                .animation(.linear(duration: 0.1), value: manager.currentTime)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            seekToPosition(location.x / geometry.size.width)
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let progress = min(max(0, value.location.x / geometry.size.width), 1)
                                    seekToPosition(progress)
                                }
                        )
                    }
                    .frame(height: 4)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(manager.currentTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        Text(formatTime(manager.duration))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                // Glassy appearance with material effect
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard manager.duration > 0 else { return 0 }
        return totalWidth * CGFloat(manager.currentTime / manager.duration)
    }
    
    private func seekToPosition(_ position: Double) {
        let newTime = position * manager.duration
        searchState.playbackManager.seek(to: newTime)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}