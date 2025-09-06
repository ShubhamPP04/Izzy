//
//  SettingsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var searchState: SearchState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Launch at login setting
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Launch at Login")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                }
                
                Text("Automatically start Izzy when you log in to your Mac")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // Favorites section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Favorites")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Text("\(searchState.favorites.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if searchState.favorites.isEmpty {
                    HStack {
                        Image(systemName: "heart")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        
                        Text("No favorites yet")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Show first few favorites as examples
                    ForEach(searchState.favorites.prefix(3), id: \.id) { favorite in
                        HStack {
                            AsyncImage(url: URL(string: favorite.thumbnailURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Text(favorite.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                    
                    if searchState.favorites.count > 3 {
                        Text("+\(searchState.favorites.count - 3) more")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // Recently played section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("Recently Played")
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    Text("\(searchState.recentlyPlayed.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if searchState.recentlyPlayed.isEmpty {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        
                        Text("No recently played songs yet")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Show first few recently played as examples
                    ForEach(searchState.recentlyPlayed.prefix(3), id: \.id) { recentlyPlayed in
                        HStack {
                            AsyncImage(url: URL(string: recentlyPlayed.thumbnailURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            Text(recentlyPlayed.title)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                    
                    if searchState.recentlyPlayed.count > 3 {
                        Text("+\(searchState.recentlyPlayed.count - 3) more")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onChange(of: launchAtLogin) { _, newValue in
            setLaunchAtLogin(newValue)
        }
        .onAppear {
            // Check current launch at login status
            launchAtLogin = isLaunchAtLoginEnabled()
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}

#Preview {
    SettingsView(searchState: SearchState())
        .frame(width: 600, height: 400)
        .padding()
        .background(Color.black.opacity(0.1))
}