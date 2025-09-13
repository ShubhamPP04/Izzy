//
//  SearchBar.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct SearchBar: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search Icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            // Search TextField
            TextField("Search...", text: $searchState.searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16, weight: .medium))
                .focused($isSearchFocused)
                .onSubmit {
                    searchState.executeSelectedResult()
                }
                .onKeyPress { keyPress in
                    handleKeyPress(keyPress)
                }
                .onAppear {
                    // Force focus when the text field appears
                    isSearchFocused = true
                }
                // Keep focus when text changes (including when cleared)
                .onChange(of: searchState.searchText) { _, _ in
                    DispatchQueue.main.async {
                        isSearchFocused = true
                    }
                }
            
            // Loading indicator
            if searchState.isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .modifier(SearchBarBackgroundModifier())
        .onChange(of: windowManager.isVisible) { _, isVisible in
            if isVisible {
                // Focus immediately when window becomes visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            } else {
                // Remove focus when window is hidden
                isSearchFocused = false
            }
        }
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .escape:
            windowManager.hideWindow()
            return .handled
        case .upArrow:
            searchState.moveSelectionUp()
            return .handled
        case .downArrow:
            searchState.moveSelectionDown()
            return .handled
        default:
            return .ignored
        }
    }
}

// Custom ViewModifier for the search bar background
struct SearchBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 25)
                    .fill(.ultraThinMaterial)
            }
    }
}

// Conditional background modifier for liquid glass
struct SearchBarBackgroundModifier: ViewModifier {
    @ObservedObject private var liquidGlassSettings = LiquidGlassSettings.shared
    
    func body(content: Content) -> some View {
        if liquidGlassSettings.isEnabled {
            content
                .liquidGlass(isInteractive: true, cornerRadius: 25, intensity: 0.3)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.ultraThinMaterial)
                }
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
        }
    }
}

#Preview {
    SearchBar(
        searchState: SearchState(),
        windowManager: WindowManager()
    )
    .frame(width: 600, height: 50)
    .padding()
    .background(Color.black.opacity(0.3))
}