//
//  HomeView.swift
//  Izzy
//
//  Created by GitHub Copilot on 07/09/25.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject var windowManager: WindowManager
    @Binding var selectedTab: Int
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "house.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("Welcome to Izzy")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("Your personal music companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Quick Actions Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    // Search Quick Action
                    QuickActionCard(
                        icon: "magnifyingglass",
                        title: "Search",
                        subtitle: "Find your favorite music",
                        color: .blue
                    ) {
                        selectedTab = 1 // Switch to Search tab
                    }
                    
                    // Favorites Quick Action
                    QuickActionCard(
                        icon: "heart.fill",
                        title: "Favorites",
                        subtitle: "Your liked songs",
                        color: .red
                    ) {
                        selectedTab = 2 // Switch to Favorites tab
                    }
                    
                    // Recently Played Quick Action
                    QuickActionCard(
                        icon: "clock.fill",
                        title: "Recently Played",
                        subtitle: "Continue listening",
                        color: .green
                    ) {
                        selectedTab = 3 // Switch to Recently Played tab
                    }
                    
                    // Settings Quick Action
                    QuickActionCard(
                        icon: "gear",
                        title: "Settings",
                        subtitle: "Customize your experience",
                        color: .gray
                    ) {
                        selectedTab = 4 // Switch to Settings tab
                    }
                }
                .padding(.horizontal, 20)
                
                // Now Playing Section (if there's a current track)
                if let currentTrack = searchState.playbackManager.currentTrack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Now Playing")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            // Album Art with AsyncImage
                            AsyncImage(url: URL(string: currentTrack.thumbnailURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Image(systemName: "music.note")
                                            .foregroundColor(.secondary)
                                            .font(.title2)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentTrack.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(currentTrack.artist)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Play/Pause button
                            Button(action: {
                                if searchState.playbackManager.isPlaying {
                                    searchState.playbackManager.pause()
                                } else {
                                    searchState.playbackManager.resume()
                                }
                            }) {
                                Image(systemName: searchState.playbackManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Recent Activity or Stats section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Stats")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        StatCard(
                            icon: "heart.fill",
                            value: "\(searchState.favorites.count)",
                            label: "Favorites",
                            color: .red
                        )
                        
                        StatCard(
                            icon: "clock.fill",
                            value: "\(searchState.recentlyPlayed.count)",
                            label: "Recent",
                            color: .green
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: false)
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    HomeView(
        searchState: SearchState(),
        windowManager: WindowManager(),
        selectedTab: Binding.constant(0)
    )
    .frame(width: 600, height: 650)
    .background(Color.black.opacity(0.3))
}
