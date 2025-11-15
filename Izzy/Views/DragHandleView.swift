//
//  DragHandleView.swift
//  Izzy
//
//  Created by Assistant on 15/11/25.
//

import SwiftUI
import AppKit

/// A drag handle view that enables window dragging from a specific area
struct DragHandleView: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .overlay(
                    WindowDragGesture()
                )
        }
        .frame(height: 32) // Drag handle height
    }
}

/// A custom view that handles window dragging using NSWindow methods
struct WindowDragGesture: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        return DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {
        // No updates needed
    }
}

/// NSView that enables window dragging
class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        // Perform window drag
        window?.performDrag(with: event)
        super.mouseDown(with: event)
    }
}
