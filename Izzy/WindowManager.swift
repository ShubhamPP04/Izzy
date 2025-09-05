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
        // Prevent multiple rapid calls
        guard !isVisible else { return }
        
        // If panel already exists, just show it
        if let panel = floatingPanel {
            isVisible = true
            // Only activate when explicitly showing the panel (via hotkey)
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFront(nil)
            panel.makeKey()
            panel.center()
            return
        }
        
        // Create new floating panel
        let panel = FloatingPanel(
            view: {
                // Create the music search view with full functionality
                MusicSearchView(
                    searchState: self.searchState ?? SearchState(),
                    windowManager: self
                )
            },
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 650),
            didClose: {
                self.floatingPanel = nil
                self.isVisible = false
            }
        )
        
        // Restore search state before showing
        searchState?.restoreState()
        
        // Update visibility state
        isVisible = true
        
        // Activate app and show panel with proper sequence
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFront(nil)
        panel.makeKey()
        panel.center()
        
        // Enable remote control events for this window
        panel.becomeFirstResponder()
        
        // Store reference
        floatingPanel = panel
    }
    
    func hideWindow() {
        guard let panel = floatingPanel else { return }
        
        // Prevent multiple rapid calls
        guard isVisible else { return }
        
        // Save current state before hiding
        searchState?.saveState()
        
        // Close the panel
        panel.close()
        
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
    }
    
    func toggleVisibility() {
        if isVisible {
            hideWindow()
        } else {
            showWindow()
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
        let compactFrame = NSRect(x: 0, y: 0, width: 600, height: 650)
        
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
}