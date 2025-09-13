//
//  ContentView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .modifier(ContentViewBackgroundModifier())
    }
}

// Conditional background modifier for ContentView
struct ContentViewBackgroundModifier: ViewModifier {
    @ObservedObject private var liquidGlassSettings = LiquidGlassSettings.shared
    
    func body(content: Content) -> some View {
        if liquidGlassSettings.isEnabled {
            content
                .liquidGlassContainer()
                .liquidGlass(isInteractive: false, cornerRadius: 15, intensity: 0.2)
        } else {
            content
                // Keep original ContentView appearance when liquid glass is off
        }
    }
}

#Preview {
    ContentView()
}
