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
    @Binding var scrollOffset: CGFloat
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoUpdateEnabled") private var autoUpdateEnabled = true
    @AppStorage("musicSource") private var musicSource = MusicSource.youtubeMusic.rawValue
    @AppStorage("customHomeName") private var customHomeName = "User"
    @AppStorage("startupTab") private var startupTab = 1 // 0 = Home, 1 = Search, 2 = Favorites, 3 = Recently Played, 4 = Settings, 5 = Playlists
    @AppStorage("geminiApiKey") private var geminiApiKey = ""
    @StateObject private var updateManager = UpdateManager.shared
    @State private var isGeminiKeyVisible = false
    
    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    launchAtLoginCard
                    menuBarPlayerCard
                    miniPlayerCard
                    liquidGlassCard
                    customHomeNameCard
                    musicSourceCard
                    aiServicesCard
                    startupTabCard
                    updatesCard
                    playbackControlsCard
                    favoritesCard
                    recentlyPlayedCard
                    debugOptionsCard
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
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

    @ViewBuilder
    private var headerSection: some View {
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
    }

    @ViewBuilder
    private var launchAtLoginCard: some View {
        settingsCard(spacing: 8) {
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
    }

    @ViewBuilder
    private var menuBarPlayerCard: some View {
        settingsCard(spacing: 8) {
            HStack {
                Image(systemName: "menubar.dock.rectangle")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Menu Bar Player")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { SimpleMenuBarManager.shared.isEnabled },
                        set: { SimpleMenuBarManager.shared.isEnabled = $0 }
                    )
                )
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
                .onAppear {
                    if let windowManager {
                        SimpleMenuBarManager.shared.configure(searchState: searchState, windowManager: windowManager)
                    }
                }
            }

            Text("Show a compact music player in the menu bar with playback controls")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var miniPlayerCard: some View {
        settingsCard(spacing: 8) {
            HStack {
                Image(systemName: "pip")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Mini Player")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { MiniPlayerManager.shared.isEnabled },
                        set: { MiniPlayerManager.shared.isEnabled = $0 }
                    )
                )
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
                .onAppear {
                    MiniPlayerManager.shared.configure(searchState: searchState)
                }
            }

            Text("Show a draggable, resizable mini player window with liquid glass design and full playback controls")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var liquidGlassCard: some View {
        settingsCard(spacing: 8) {
            HStack {
                Image(systemName: "drop.triangle")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Liquid Glass Effect")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { LiquidGlassSettings.shared.isEnabled },
                        set: { LiquidGlassSettings.shared.isEnabled = $0 }
                    )
                )
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
            }

            Text("Transform the app with a stunning liquid glass aesthetic with full transparency and dark mode")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var customHomeNameCard: some View {
        settingsCard(spacing: 8) {
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
    }

    @ViewBuilder
    private var musicSourceCard: some View {
        settingsCard {
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

            Picker(
                "Music Source",
                selection: Binding(
                    get: { MusicSource(rawValue: musicSource) ?? .youtubeMusic },
                    set: { newSource in
                        let oldSource = musicSource
                        musicSource = newSource.rawValue

                        if oldSource != newSource.rawValue {
                            searchState.musicSearchManager.clearCacheForMusicSourceChange()
                            print("🔄 Music source changed from '\(oldSource)' to '\(newSource.rawValue)' - cache cleared")
                        }
                    }
                )
            ) {
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
    }

    @ViewBuilder
    private var aiServicesCard: some View {
        settingsCard {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                    .foregroundColor(.purple)
                    .font(.system(size: 14, weight: .medium))

                Text("AI Services")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }

            Text("Connect your Gemini 2.5 Flash key to unlock smarter AI Search recommendations.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if isGeminiKeyVisible {
                        TextField("Gemini API Key", text: $geminiApiKey)
                            .autocorrectionDisabled()
                            .liquidGlassTextField()
                    } else {
                        SecureField("Gemini API Key", text: $geminiApiKey)
                            .autocorrectionDisabled()
                            .liquidGlassTextField()
                    }
                }
                .onChange(of: geminiApiKey) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed != geminiApiKey {
                        geminiApiKey = trimmed
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        isGeminiKeyVisible.toggle()
                    } label: {
                        Label(isGeminiKeyVisible ? "Hide Key" : "Show Key", systemImage: isGeminiKeyVisible ? "eye.slash" : "eye")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)

                    if !geminiApiKey.isEmpty {
                        Divider()
                            .frame(height: 16)
                        Button {
                            geminiApiKey = ""
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if !geminiApiKey.isEmpty {
                        Label("Key saved", systemImage: "checkmark.shield.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Label("Required for AI Search", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            Link("Get a Gemini API key", destination: URL(string: "https://ai.google.dev/gemini-api/docs/get-started")!)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    private var startupTabCard: some View {
        settingsCard {
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

            Picker("Startup Tab", selection: $startupTab) {
                startupTabOption(icon: "house.fill", title: "Home", tag: 0)
                startupTabOption(icon: "magnifyingglass", title: "Search", tag: 1)
                startupTabOption(icon: "heart.fill", title: "Favorites", tag: 2)
                startupTabOption(icon: "clock.fill", title: "Recently Played", tag: 3)
                startupTabOption(icon: "music.note.list", title: "Playlists", tag: 5)
                startupTabOption(icon: "gear", title: "Settings", tag: 4)
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("This tab will be selected when Izzy opens")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var updatesCard: some View {
        settingsCard {
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

            if updateManager.isChecking {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Checking...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

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
    }

    @ViewBuilder
    private var playbackControlsCard: some View {
        settingsCard {
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

            HStack {
                Text("Center Playback Buttons")
                    .font(.system(size: 14))

                Spacer()

                Toggle(
                    "",
                    isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: "centerPlaybackButtons") },
                        set: { UserDefaults.standard.set($0, forKey: "centerPlaybackButtons") }
                    )
                )
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
            }

            Text("When enabled, Previous, Play/Pause, and Next buttons will be centered. When disabled, they will be left-aligned.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Text("Minimal Playback Player")
                    .font(.system(size: 14))

                Spacer()

                Toggle(
                    "",
                    isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: "minimalPlaybackPlayer") },
                        set: { UserDefaults.standard.set($0, forKey: "minimalPlaybackPlayer") }
                    )
                )
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle())
            }

            Text("When enabled, the playback player will have a more elegant and compact design with a refined horizontal layout, subtle visual elements, and integrated controls.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var favoritesCard: some View {
        settingsCard(fill: Color.primary.opacity(0.05)) {
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
                emptyStateRow(icon: "heart", message: "No favorites yet")
            } else {
                ForEach(searchState.favorites.prefix(3), id: \.id) { favorite in
                    mediaRow(title: favorite.title, thumbnailURL: favorite.thumbnailURL)
                }

                if searchState.favorites.count > 3 {
                    Text("+\(searchState.favorites.count - 3) more")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var recentlyPlayedCard: some View {
        settingsCard(fill: Color.primary.opacity(0.05)) {
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
                emptyStateRow(icon: "clock", message: "No recently played songs yet")
            } else {
                ForEach(searchState.recentlyPlayed.prefix(3), id: \.id) { recent in
                    mediaRow(title: recent.title, thumbnailURL: recent.thumbnailURL)
                }

                if searchState.recentlyPlayed.count > 3 {
                    Text("+\(searchState.recentlyPlayed.count - 3) more")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var debugOptionsCard: some View {
        settingsCard(fill: Color.orange.opacity(0.05)) {
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
    }

    @ViewBuilder
    private func startupTabOption(icon: String, title: String, tag: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 14))
        }
        .tag(tag)
    }

    @ViewBuilder
    private func emptyStateRow(icon: String, message: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func mediaRow(title: String, thumbnailURL: String?) -> some View {
        HStack {
            AsyncImage(url: URL(string: thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 24, height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer()
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(spacing: CGFloat = 12, fill: Color = Color.primary.opacity(0.05), @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(fill)
        )
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
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
    SettingsView(searchState: SearchState(), windowManager: nil, scrollOffset: Binding.constant(0))
        .frame(width: 600, height: 400)
        .padding()
        .background(Color.black.opacity(0.1))
}
