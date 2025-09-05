//
//  IzzyApp.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import AppKit

@main
struct IzzyApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            // Create an empty, invisible view that immediately hides itself
            EmptyView()
                .frame(width: 0, height: 0)
                .background(WindowAccessor { window in
                    // Immediately hide the window before it can be seen
                    window.setIsVisible(false)
                    window.orderOut(nil)
                    window.alphaValue = 0
                    appCoordinator.setupWindow(window)
                })
                .onAppear {
                    // 🔋 BATTERY OPTIMIZATION: Configure app for minimal battery usage
                    NSApp.setActivationPolicy(.accessory) // No dock icon, reduces background CPU
                    
                    // 🔋 Set low priority for non-critical app operations
                    DispatchQueue.global(qos: .utility).async {
                        // 🔋 Initialize app coordinator on utility queue to reduce main thread load
                        DispatchQueue.main.async {
                            appCoordinator.initializeApp()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    // Save state before app terminates
                    appCoordinator.handleAppTermination()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// Helper to access the underlying NSWindow
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 0, height: 0)
        
        // Immediately hide the window when the view is created
        DispatchQueue.main.async {
            if let window = view.window {
                window.setIsVisible(false)
                window.orderOut(nil)
                window.alphaValue = 0
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            // Ensure window stays hidden
            window.setIsVisible(false)
            window.orderOut(nil)
            window.alphaValue = 0
            callback(window)
        }
    }
}
