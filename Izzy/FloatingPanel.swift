//
//  FloatingPanel.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import AppKit

final class FloatingPanel: NSPanel {
    private let didClose: () -> Void
    
    init(
        view: () -> some View,
        contentRect: NSRect,
        didClose: @escaping () -> Void
    ) {
        self.didClose = didClose
        
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
        
        // 🔋 Reduce GPU usage with optimized background settings
        isOpaque = false
        backgroundColor = NSColor.clear
        hasShadow = false
        
        // 🔋 Optimize window behavior for minimal system impact
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        
        // 🔋 Reduce rendering overhead
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = true
        
        // Hide all traffic light buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // Sets animations accordingly
        animationBehavior = .utilityWindow
        
        // Set the content view
        contentView = NSHostingView(rootView: view())
        
        // Make sure window accepts first responder
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
    }
    
    // Close automatically when out of focus, e.g. outside click
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
}