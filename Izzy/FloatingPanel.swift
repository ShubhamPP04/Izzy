//
//  FloatingPanel.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import AppKit

final class FloatingPanel: NSPanel, NSWindowDelegate {
    private let didClose: () -> Void
    private var windowManager: WindowManager?
    
    init(
        view: () -> some View,
        contentRect: NSRect,
        didClose: @escaping () -> Void,
        windowManager: WindowManager? = nil
    ) {
        self.didClose = didClose
        self.windowManager = windowManager
        
        super.init(
            contentRect: contentRect,
            styleMask: [
                .titled,
                .resizable,
                .closable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        // 🔋 BATTERY OPTIMIZATION: Configure window for better power efficiency
        isFloatingPanel = true
        level = .floating
        
        // 🔋 Reduce GPU usage with optimized background settings for liquid glass
        isOpaque = false
        backgroundColor = NSColor.clear
        hasShadow = false
        
        // Enhanced liquid glass window properties
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        styleMask.insert(.fullSizeContentView)
        
        // Enable advanced compositing for liquid glass effects
        if #available(macOS 10.14, *) {
            self.appearance = NSAppearance(named: .darkAqua)
        }
        
        // 🔋 Optimize window behavior for minimal system impact  
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isMovableByWindowBackground = false
        // Remove hidesOnDeactivate to prevent automatic hiding when losing focus
        // hidesOnDeactivate = true
        
        // Hide all traffic light buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // Sets animations accordingly
        animationBehavior = .utilityWindow
        
        // Set the window delegate to track focus changes
        self.delegate = self
        
        // Create the content view
        let hostingView = NSHostingView(rootView: view())
        contentView = hostingView
        
        // Make sure window accepts first responder
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
    }
    
    // Remove the resignKey method to prevent automatic closing when losing focus
    /*
    override func resignKey() {
        super.resignKey()
        
        // IMPORTANT: When the panel loses focus, also deactivate the app
        // This ensures other apps can properly receive input events
        DispatchQueue.main.async {
            // Only deactivate if there are no other key windows from this app
            if NSApp.keyWindow == nil || NSApp.keyWindow == self {
                NSApp.deactivate()
            }
        }
        
        close()
    }
    */
    
    // Close and toggle presentation, so that it matches the current state of the panel
    override func close() {
        super.close()
        didClose()
    }
    
    // Required so that text inputs inside the panel can receive focus
    override var canBecomeKey: Bool {
        return true
    }
    
    // Allow window to become main for proper input handling
    override var canBecomeMain: Bool {
        return true
    }
    
    // Accept first responder for keyboard input
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // Method to update window appearance for liquid glass
    func updateLiquidGlassAppearance(enabled: Bool) {
        if enabled {
            backgroundColor = NSColor.clear
            if #available(macOS 10.14, *) {
                self.appearance = NSAppearance(named: .darkAqua)
            }
        } else {
            backgroundColor = NSColor.clear // Keep clear for normal mode too
            if #available(macOS 10.14, *) {
                self.appearance = nil // Use system appearance
            }
        }
    }
    
    // MARK: - Window State Tracking
    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        // Notify WindowManager when window is hidden by system (clicking on background app)
        if let wm = windowManager {
            DispatchQueue.main.async {
                wm.syncVisibilityState(false)
            }
        }
    }
    
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        // Notify WindowManager when window becomes visible
        if let wm = windowManager {
            DispatchQueue.main.async {
                wm.syncVisibilityState(true)
            }
        }
    }
    
    override func orderBack(_ sender: Any?) {
        super.orderBack(sender)
        // Notify WindowManager when window is moved to back
        if let wm = windowManager {
            DispatchQueue.main.async {
                wm.syncVisibilityState(false)
            }
        }
    }
    
    // MARK: - NSWindowDelegate
    func windowDidResignKey(_ notification: Notification) {
        print("🔄 Window resigned key (lost focus) - syncing state to hidden")
        if let wm = windowManager {
            DispatchQueue.main.async {
                wm.syncVisibilityState(false)
            }
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("🔄 Window became key (gained focus) - syncing state to visible")
        if let wm = windowManager {
            DispatchQueue.main.async {
                wm.syncVisibilityState(true)
            }
        }
    }
}