//
//  WindowManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    @Published var isVisible: Bool = false

    private var floatingPanel: FloatingPanel?
    private var isConfigured = false
    weak var searchState: SearchState?
    weak var hotkeyManager: GlobalHotkeyManager?

    // Window position persistence
    private let windowPositionKey = "FloatingPanelPosition"
    private var shouldCenterWindow = false

    private func makeFloatingPanel() -> FloatingPanel {
        let panel = FloatingPanel(
            view: {
                // Create the music search view with full functionality
                let baseView = MusicSearchView(
                    searchState: self.searchState ?? SearchState(),
                    windowManager: self
                )

                if let hotkeyManager = self.hotkeyManager {
                    return AnyView(baseView.environmentObject(hotkeyManager))
                } else {
                    return AnyView(baseView)
                }
            },
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 750),
            didClose: {
                print("🔚 Panel closed callback")
                // Position is saved in hideWindow() before panel.close()
                self.floatingPanel = nil
                self.isVisible = false
            },
            windowManager: self,
            playbackManager: self.searchState?.playbackManager
        )

        // Restore search state before the panel is ever shown
        searchState?.restoreState()

        return panel
    }

    /// Pre-create the floating panel so the first hotkey press feels instant.
    func prewarmWindow() {
        guard floatingPanel == nil else { return }
        print("🔥 Prewarming floating panel for instant hotkey")
        floatingPanel = makeFloatingPanel()

        // Keep it hidden/off-screen until explicitly shown
        floatingPanel?.setIsVisible(false)
        floatingPanel?.orderOut(nil)
    }
    
    func setupWindow(_ window: NSWindow) {
        // Completely hide the main SwiftUI window since we only use FloatingPanel
        window.setIsVisible(false)
        window.orderOut(nil)
        window.alphaValue = 0
        window.level = NSWindow.Level(rawValue: -1000) // Put it way below everything
        window.ignoresMouseEvents = true
        
        // Make sure it never appears
        window.collectionBehavior = [.ignoresCycle, .stationary]
        
        print("🔒 Main SwiftUI window hidden and disabled")
    }
    
    func showWindow() {
        print("🔍 showWindow called - current isVisible: \(isVisible)")

        // 🔋 BATTERY EFFICIENCY: Save playback state before showing window
        searchState?.playbackManager.savePlaybackState()

        // Build panel ahead of time if needed
        if floatingPanel == nil {
            floatingPanel = makeFloatingPanel()
        }

        // If panel already exists and is not visible, just show it
        if let panel = floatingPanel {
            if !isVisible {
                print("📱 Showing existing panel")
                isVisible = true

                // Immediate activation sequence for better responsiveness
                NSApp.activate(ignoringOtherApps: true)
                panel.orderFront(nil)
                panel.makeKeyAndOrderFront(nil)

                // Restore position instead of centering
                if shouldCenterWindow {
                    panel.center()
                    shouldCenterWindow = false
                } else {
                    restoreWindowPosition(panel)
                }

                // Ensure focus
                DispatchQueue.main.async {
                    panel.makeKey()
                }
            } else {
                print("⚠️ Panel already visible")
            }
            return
        }

        print("🆕 Creating new floating panel")

        // Create new floating panel
        let panel = makeFloatingPanel()

        // Update visibility state immediately
        isVisible = true

        // Optimized activation sequence
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Restore position or center on first launch
        if shouldCenterWindow {
            panel.center()
            shouldCenterWindow = false
        } else {
            restoreWindowPosition(panel)
        }

        // Store reference
        floatingPanel = panel

        // Removed scroll position restoration notification to allow natural persistence

        print("✅ Panel created and shown successfully")
    }
    
    func hideWindow() {
        print("🙈 hideWindow called - current isVisible: \(isVisible)")
        guard let panel = floatingPanel, isVisible else {
            print("⚠️ No panel to hide or already hidden")
            return
        }

        // Save window position before hiding
        saveWindowPosition(panel)

        // Save current state before hiding
        searchState?.saveState()

        // 🔋 BATTERY EFFICIENCY: Save playback state when hiding window
        searchState?.playbackManager.savePlaybackState()

        // Removed scroll position save notification - letting views handle their own state

        // Update state immediately for better responsiveness
        isVisible = false
        print("🔒 Panel marked as hidden")

        // Order out but keep the panel warm for instant re-show
        panel.orderOut(nil)

        // IMPORTANT: Release app focus so other apps can work properly
        // This ensures that when the panel is hidden, other apps can receive input
        DispatchQueue.main.async {
            // Find the previously active application and activate it
            let runningApps = NSWorkspace.shared.runningApplications
            if let previousApp = runningApps.first(where: { $0.isActive && $0.bundleIdentifier != Bundle.main.bundleIdentifier }) {
                previousApp.activate(options: [])
            } else {
                // If no other app is active, just deactivate this app
                NSApp.deactivate()
            }
        }

        print("✅ Panel hidden successfully")
    }
    
    func toggleVisibility() {
        print("🔄 Toggle visibility called - current state: \(isVisible)")
        if isVisible {
            print("🔄 Hiding window...")
            hideWindow()
        } else {
            print("🔄 Showing window...")
            showWindow()
        }
    }
    
    // MARK: - Window State Synchronization
    func syncVisibilityState(_ visible: Bool) {
        print("🔄 Syncing visibility state: \(visible) (was: \(isVisible))")
        if isVisible != visible {
            isVisible = visible
            print("✅ Visibility state synchronized to: \(visible)")
        }
    }
    
    func expandWindow() {
        guard let panel = floatingPanel else { return }
        
        // Get screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Calculate expanded size (80% of screen)
        let expandedWidth = screenFrame.width * 0.8
        let expandedHeight = screenFrame.height * 0.8
        
        // Center the expanded window
        let expandedX = screenFrame.midX - expandedWidth / 2
        let expandedY = screenFrame.midY - expandedHeight / 2
        
        let expandedFrame = NSRect(
            x: expandedX,
            y: expandedY,
            width: expandedWidth,
            height: expandedHeight
        )
        
        // Animate to expanded size
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(expandedFrame, display: true)
        }
    }
    
    func contractWindow() {
        guard let panel = floatingPanel else { return }

        // Return to original compact size
        let compactFrame = NSRect(x: 0, y: 0, width: 600, height: 750)

        // Animate back to compact size and center
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(compactFrame, display: true)
        } completionHandler: {
            // Center the window after animation
            panel.center()
        }
    }

    // MARK: - Window Position Management

    func saveWindowPosition(_ window: NSWindow) {
        let frame = window.frame
        let frameString = NSStringFromRect(frame)
        UserDefaults.standard.set(frameString, forKey: windowPositionKey)
        print("💾 Saved window position: \(frameString)")
    }

    func restoreWindowPosition(_ window: NSWindow) {
        guard let frameString = UserDefaults.standard.string(forKey: windowPositionKey) else {
            print("⚠️ No saved position found, centering window")
            window.center()
            return
        }

        let frame = NSRectFromString(frameString)

        // Validate the frame is within screen bounds
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if screenFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) {
                window.setFrame(frame, display: true)
                print("✅ Restored window position: \(frameString)")
            } else {
                print("⚠️ Saved position is off-screen, centering window")
                window.center()
            }
        } else {
            window.center()
        }
    }

    /// Centers the window and marks it for centering on next show
    func centerWindowPosition() {
        shouldCenterWindow = true
        if let panel = floatingPanel, isVisible {
            panel.center()
            saveWindowPosition(panel)
            print("✅ Window centered")
        }
    }
}
