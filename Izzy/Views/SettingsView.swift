//
//  SettingsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI
import ServiceManagement
import AppKit
import Combine

struct SettingsView: View {
    @ObservedObject var searchState: SearchState
    let windowManager: WindowManager?
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoUpdateEnabled") private var autoUpdateEnabled = true
    @AppStorage("musicSource") private var musicSource = MusicSource.youtubeMusic.rawValue
    @AppStorage("customHomeName") private var customHomeName = "Shubham"
    @AppStorage("startupTab") private var startupTab = 1 // 0 = Home, 1 = Search, 2 = Favorites, 3 = Recently Played, 4 = Settings, 5 = Playlists
    @StateObject private var updateManager = UpdateManager.shared
    
    var body: some View {
        ScrollView {
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
                
                // Menu Bar Player setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "menubar.dock.rectangle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Menu Bar Player")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { SimpleMenuBarManager.shared.isEnabled },
                            set: { SimpleMenuBarManager.shared.isEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                        .onAppear {
                            if let windowManager = windowManager {
                                SimpleMenuBarManager.shared.configure(searchState: searchState, windowManager: windowManager)
                            }
                        }
                    }
                    
                    Text("Show a compact music player in the menu bar with playback controls")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Liquid Glass setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "drop.triangle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Liquid Glass Effect")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { LiquidGlassSettings.shared.isEnabled },
                            set: { LiquidGlassSettings.shared.isEnabled = $0 }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                    }
                    
                    Text("Transform the app with a stunning liquid glass aesthetic with full transparency and dark mode")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Custom Home Name setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Your Name")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    TextField("Enter your name", text: $customHomeName)
                        .liquidGlassTextField()
                        .frame(maxWidth: 200)
                    
                    Text("This name will appear on the home screen")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Music Source section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Music Source")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    Text("Choose your preferred music streaming service")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // Music source picker
                    Picker("Music Source", selection: Binding(
                        get: { MusicSource(rawValue: musicSource) ?? .youtubeMusic },
                        set: { newSource in
                            let oldSource = musicSource
                            musicSource = newSource.rawValue
                            
                            // Clear search cache when music source changes
                            if oldSource != newSource.rawValue {
                                searchState.musicSearchManager.clearCacheForMusicSourceChange()
                                print("🔄 Music source changed from '\(oldSource)' to '\(newSource.rawValue)' - cache cleared")
                            }
                        }
                    )) {
                        ForEach(MusicSource.allCases, id: \.self) { source in
                            HStack {
                                Image(systemName: source.icon)
                                    .foregroundColor(.blue)
                                    .font(.system(size: 12))
                                Text(source.displayName)
                                    .font(.system(size: 14))
                            }
                            .tag(source)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if MusicSource(rawValue: musicSource) == .jioSaavn {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                            
                            Text("JioSaavn integration provides access to Indian music library with high-quality streaming.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Icon-only Mode section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Navigation Style")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    Text("Choose how navigation tabs are displayed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // Icon-only mode toggle
                    HStack {
                        Text("Icon-only Navigation")
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        Toggle("", isOn: .init(
                            get: { UserDefaults.standard.bool(forKey: "iconOnlyNavigation") },
                            set: { UserDefaults.standard.set($0, forKey: "iconOnlyNavigation") }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                    }
                    
                    Text("When enabled, navigation tabs will show only icons without text labels")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Startup Tab section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cursorarrow.click")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Startup Tab")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    Text("Choose which tab opens when you launch Izzy")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // Startup tab picker
                    Picker("Startup Tab", selection: $startupTab) {
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text("Home")
                                .font(.system(size: 14))
                        }
                        .tag(0)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text("Search")
                                .font(.system(size: 14))
                        }
                        .tag(1)
                        
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text("Favorites")
                                .font(.system(size: 14))
                        }
                        .tag(2)
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text("Recently Played")
                                .font(.system(size: 14))
                        }
                        .tag(3)
                        
                        HStack {
                            Image(systemName: "music.note.list")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text("Playlists")
                                .font(.system(size: 14))
                        }
                        .tag(5)
                        
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            Text("Settings")
                                .font(.system(size: 14))
                        }
                        .tag(4)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("This tab will be selected when Izzy opens")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Updates section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Updates")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    Text("Keep Izzy up to date with the latest features and improvements")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // Auto-update toggle
                    HStack {
                        Text("Automatic Updates")
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        Toggle("", isOn: $autoUpdateEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle())
                    }
                    
                    HStack {
                        Button("Check for Updates") {
                            updateManager.checkForUpdates()
                        }
                        .disabled(updateManager.isChecking)
                        
                        Spacer()
                        
                        if updateManager.isUpdateAvailable {
                            Button("Download Update") {
                                updateManager.downloadUpdate()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Text(updateManager.updateStatus)
                        .font(.system(size: 12))
                        .foregroundColor(updateManager.isUpdateAvailable ? .blue : .secondary)
                    
                    if !updateManager.updateMessage.isEmpty {
                        Text(updateManager.updateMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    // Show checking indicator
                    if updateManager.isChecking {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("Checking...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Development note
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        
                        Text("For development builds, update checks may fail if update server is not configured.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                
                // Playback Controls section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Playback Controls")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    Text("Customize the layout of playback controls")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    // Playback button alignment
                    HStack {
                        Text("Center Playback Buttons")
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        Toggle("", isOn: .init(
                            get: { UserDefaults.standard.bool(forKey: "centerPlaybackButtons") },
                            set: { UserDefaults.standard.set($0, forKey: "centerPlaybackButtons") }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                    }
                    
                    Text("When enabled, Previous, Play/Pause, and Next buttons will be centered. When disabled, they will be left-aligned.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    // Minimal playback player
                    HStack {
                        Text("Minimal Playback Player")
                            .font(.system(size: 14))
                        
                        Spacer()
                        
                        Toggle("", isOn: .init(
                            get: { UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") },
                            set: { UserDefaults.standard.set($0, forKey: "minimalPlaybackPlayer") }
                        ))
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                    }
                    
                    Text("When enabled, the playback player will have a more elegant and compact design with a refined horizontal layout, subtle visual elements, and integrated controls.")
                        .font(.system(size: 11))
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
                
                // Debug section (hidden, for testing startup tab functionality)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "wrench.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Debug Options")
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    
                    Text("For testing startup tab functionality")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Button("Reset First Launch Flag") {
                        UserDefaults.standard.removeObject(forKey: "appHasBeenLaunched")
                        print("🔄 First launch flag reset - next app start will use startup tab setting")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.05))
                )
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onChange(of: launchAtLogin) { _, newValue in
            setLaunchAtLogin(newValue)
        }
        .onChange(of: autoUpdateEnabled) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "AutoUpdateEnabled")
        }
        .onChange(of: musicSource) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "musicSource")
            // Clear search results when music source changes to force refresh
            searchState.clearSearch()
        }
        .onAppear {
            // Check current launch at login status
            launchAtLogin = isLaunchAtLoginEnabled()
            // Load auto-update setting
            autoUpdateEnabled = UserDefaults.standard.bool(forKey: "AutoUpdateEnabled")
            // Check for updates when settings view appears
            updateManager.checkForUpdates()
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
    SettingsView(searchState: SearchState(), windowManager: nil)
        .frame(width: 600, height: 400)
        .padding()
        .background(Color.black.opacity(0.1))
}
