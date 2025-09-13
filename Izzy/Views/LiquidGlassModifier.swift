//
//  LiquidGlassModifier.swift
//  Izzy
//
//  Created by Shubham Kumar on 13/09/25.
//

import SwiftUI

// MARK: - Liquid Glass Settings Store
class LiquidGlassSettings: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "liquidGlassEnabled")
        }
    }
    
    static let shared = LiquidGlassSettings()
    
    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "liquidGlassEnabled")
    }
}

// MARK: - Liquid Glass View Modifier
struct LiquidGlassModifier: ViewModifier {
    @ObservedObject private var settings = LiquidGlassSettings.shared
    let isInteractive: Bool
    let cornerRadius: CGFloat
    let intensity: Double
    
    init(isInteractive: Bool = true, cornerRadius: CGFloat = 20, intensity: Double = 0.3) {
        self.isInteractive = isInteractive
        self.cornerRadius = cornerRadius
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        if settings.isEnabled {
            content
                .background {
                    LiquidGlassBackground(
                        isInteractive: isInteractive,
                        cornerRadius: cornerRadius,
                        intensity: intensity
                    )
                }
                .foregroundStyle(.primary.opacity(0.9))
                .preferredColorScheme(.dark) // Force dark mode when liquid glass is active
                .environment(\.colorScheme, .dark) // Force dark mode environment
        } else {
            content
        }
    }
}

// MARK: - Liquid Glass Background (Performance Optimized - No Animations)
struct LiquidGlassBackground: View {
    let isInteractive: Bool
    let cornerRadius: CGFloat
    let intensity: Double
    
    var body: some View {
        ZStack {
            // Base transparent background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.clear)
            
            // Glass effect layers - static only for performance
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(intensity * 0.25),
                            .white.opacity(intensity * 0.15),
                            .white.opacity(intensity * 0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.black.opacity(0.1))
                )
            
            // Static glass border effect
            if isInteractive {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .blue.opacity(0.2),
                                .purple.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            
            // Inner highlight
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.4),
                            .white.opacity(0.1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
                .padding(1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Liquid Glass Container
struct LiquidGlassContainer<Content: View>: View {
    @ObservedObject private var settings = LiquidGlassSettings.shared
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        if settings.isEnabled {
            content
                .background(.clear)
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
        } else {
            content
        }
    }
}

// MARK: - View Extensions
extension View {
    func liquidGlass(isInteractive: Bool = true, cornerRadius: CGFloat = 20, intensity: Double = 0.3) -> some View {
        self.modifier(LiquidGlassModifier(isInteractive: isInteractive, cornerRadius: cornerRadius, intensity: intensity))
    }
    
    func liquidGlassContainer(cornerRadius: CGFloat = 20) -> some View {
        LiquidGlassContainer(cornerRadius: cornerRadius) {
            self
        }
    }
    
    /// Custom liquid glass text field style for seamless integration
    func liquidGlassTextField() -> some View {
        self.modifier(LiquidGlassTextFieldModifier())
    }
    
    /// Custom liquid glass button style for seamless integration
    func liquidGlassButton(prominence: LiquidGlassButtonProminence = .standard) -> some View {
        self.modifier(LiquidGlassButtonModifier(prominence: prominence))
    }
}

// MARK: - Liquid Glass Text Field Style
struct LiquidGlassTextFieldModifier: ViewModifier {
    @ObservedObject private var settings = LiquidGlassSettings.shared
    
    func body(content: Content) -> some View {
        if settings.isEnabled {
            content
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlass(isInteractive: true, cornerRadius: 8, intensity: 0.2)
        } else {
            content
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

// MARK: - Liquid Glass Button Style
enum LiquidGlassButtonProminence {
    case standard
    case prominent
}

struct LiquidGlassButtonModifier: ViewModifier {
    @ObservedObject private var settings = LiquidGlassSettings.shared
    let prominence: LiquidGlassButtonProminence
    
    func body(content: Content) -> some View {
        if settings.isEnabled {
            content
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .liquidGlass(
                    isInteractive: true, 
                    cornerRadius: 8, 
                    intensity: prominence == .prominent ? 0.4 : 0.3
                )
        } else {
            if prominence == .prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Liquid Glass Full Window Background (Performance Optimized - No Animations)
struct LiquidGlassWindowBackground: View {
    @ObservedObject private var settings = LiquidGlassSettings.shared
    
    var body: some View {
        if settings.isEnabled {
            ZStack {
                // Pure liquid glass base - static only
                Rectangle()
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                // Static glass layers for depth
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.08),
                                .white.opacity(0.03),
                                .white.opacity(0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
                
                // Static glass gradient overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .blue.opacity(0.08),
                                .purple.opacity(0.06),
                                .blue.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
                
                // Static subtle radial overlay
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.08),
                                .white.opacity(0.04),
                                .clear
                            ],
                            center: .center,
                            startRadius: 100,
                            endRadius: 500
                        )
                    )
                    .ignoresSafeArea()
                    .opacity(0.6)
            }
        } else {
            Color.clear
        }
    }
}