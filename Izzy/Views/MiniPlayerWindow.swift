//
//  MiniPlayerWindow.swift
//  Izzy
//
//  Created by Assistant on 21/09/25.
//

import SwiftUI
import AppKit

// MARK: - Custom Mini Player Window
class MiniPlayerWindow: NSWindow {
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        setupWindow()
    }
    
    private func setupWindow() {
        // Basic window configuration
        isOpaque = false
        backgroundColor = NSColor.clear
        hasShadow = true
        level = .floating
        
        // Enable drag and resize functionality
        isMovableByWindowBackground = true
        
        // Advanced liquid glass window properties
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        styleMask.insert(.fullSizeContentView)
        
        // Collection behavior for better window management
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Enable advanced compositing for liquid glass effects
        if #available(macOS 10.14, *) {
            self.appearance = NSAppearance(named: .darkAqua)
        }
        
        // Set constraints for minimum and maximum sizes
        minSize = NSSize(width: 250, height: 100)
        maxSize = NSSize(width: 600, height: 250)
        
        // Animation behavior
        animationBehavior = .documentWindow
    }
    
    // MARK: - Drag and Resize Handling
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false // Don't steal main window status from the main app
    }
    
    override func mouseDown(with event: NSEvent) {
        // Enable window dragging on mouse down
        super.mouseDown(with: event)
    }
    
    // Custom resize behavior handled through delegate
    // NSWindow doesn't have performResize method, resize is handled automatically
    
    // MARK: - Window Appearance Methods
    func updateLiquidGlassAppearance(enabled: Bool) {
        if enabled {
            backgroundColor = NSColor.clear
            if #available(macOS 10.14, *) {
                self.appearance = NSAppearance(named: .darkAqua)
            }
        } else {
            backgroundColor = NSColor.windowBackgroundColor
            self.appearance = nil
        }
    }
    
    // Handle window close to prevent app termination
    override func performClose(_ sender: Any?) {
        // Hide the window instead of closing it to avoid affecting main app
        orderOut(sender)
        
        // Notify through notification center that window was closed
        NotificationCenter.default.post(name: NSNotification.Name("miniPlayerClosed"), object: nil)
    }
    
    // Override to handle escape key
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            performClose(nil)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // MARK: - Window Focus Behavior
    override func becomeKey() {
        super.becomeKey()
        // Don't interfere with main app's key status
    }
    
    override func resignKey() {
        super.resignKey()
        // Maintain floating behavior
    }
    
    // Resize functionality is handled automatically by NSWindow for resizable windows
}