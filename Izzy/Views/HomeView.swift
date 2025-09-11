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
    @ObservedObject var playlistManager = PlaylistManager.shared
    @Binding var selectedTab: Int
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Welcome section with more minimal design
                VStack(alignment: .leading, spacing: 8) {
                    Text("Good morning,")
                        .font(.largeTitle)
                        .fontWeight(.light)
                        .foregroundColor(.primary)
                    
                    Text(UserDefaults.standard.string(forKey: "customHomeName") ?? "Shubham")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                
                // Quick Actions Grid with more elegant design
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ], spacing: 20) {
                    // Search Quick Action
                    ElegantQuickActionCard(
                        icon: "magnifyingglass",
                        title: "Search",
                        subtitle: "Find music",
                        color: .blue
                    ) {
                        selectedTab = 1 // Switch to Search tab
                    }
                    
                    // Favorites Quick Action
                    ElegantQuickActionCard(
                        icon: "heart.fill",
                        title: "Favorites",
                        subtitle: "Liked songs",
                        color: .red
                    ) {
                        selectedTab = 2 // Switch to Favorites tab
                    }
                    
                    // Recently Played Quick Action
                    ElegantQuickActionCard(
                        icon: "clock.fill",
                        title: "Recently Played",
                        subtitle: "Continue listening",
                        color: .green
                    ) {
                        selectedTab = 3 // Switch to Recently Played tab
                    }
                    
                    // Playlists Quick Action
                    ElegantQuickActionCard(
                        icon: "music.note.list",
                        title: "Playlists",
                        subtitle: "Your collections",
                        color: .purple
                    ) {
                        selectedTab = 5 // Switch to Playlists tab
                    }
                }
                .padding(.horizontal, 20)
                
                // Now Playing Section (if there's a current track) - more minimal
                if let currentTrack = searchState.playbackManager.currentTrack {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Now Playing")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 16) {
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
                                            .font(.title3)
                                    )
                            }
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentTrack.title)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                Text(currentTrack.artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Play/Pause button with more elegant design
                            Button(action: {
                                if searchState.playbackManager.isPlaying {
                                    searchState.playbackManager.pause()
                                } else {
                                    searchState.playbackManager.resume()
                                }
                            }) {
                                Image(systemName: searchState.playbackManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Stats section with more minimal design
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Music")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        ElegantStatCard(
                            icon: "heart.fill",
                            value: "\(searchState.favorites.count)",
                            label: "Favorites",
                            color: .red
                        )
                        
                        ElegantStatCard(
                            icon: "clock.fill",
                            value: "\(searchState.recentlyPlayed.count)",
                            label: "Recent",
                            color: .green
                        )
                        
                        ElegantStatCard(
                            icon: "music.note.list",
                            value: "\(playlistManager.playlists.count)",
                            label: "Playlists",
                            color: .purple
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// More elegant quick action card with minimal design
struct ElegantQuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(1.0)
    }
}

// More elegant stat card with minimal design
struct ElegantStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
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