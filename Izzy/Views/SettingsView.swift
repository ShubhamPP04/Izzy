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
    @EnvironmentObject var hotkeyManager: GlobalHotkeyManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoUpdateEnabled") private var autoUpdateEnabled = true
    @AppStorage("musicSource") private var musicSource = MusicSource.youtubeMusic.rawValue
    @AppStorage("customHomeName") private var customHomeName = "User"
    @AppStorage("startupTab") private var startupTab = 1 // 0 = Home, 1 = Search, 2 = Favorites, 3 = Recently Played, 4 = Settings, 5 = Playlists
    @AppStorage("showAISearch") private var showAISearch = true
    @AppStorage(GlobalHotkeyManager.hotkeyDefaultsKey) private var storedHotkeyModifierRawValue = HotkeyModifier.option.rawValue
    @AppStorage("autoplayRadioEnabled") private var autoplayRadioEnabled = false
    @AppStorage("lyricsOverlayEnabled") private var lyricsOverlayEnabled = false
    @AppStorage("discordRichPresenceEnabled") private var discordRichPresenceEnabled = false
    @StateObject private var updateManager = UpdateManager.shared
    @ObservedObject private var playback = PlaybackManager.shared

    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    liquidGlassCard
                    musicSourceCard
                    playbackCard
                    launchAtLoginCard
                    hotkeyCard
                    menuBarPlayerCard
                    miniPlayerCard
                    customHomeNameCard
                    windowPositionCard
                    aiServicesCard
                    integrationsCard
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
            // Both caches are source-specific: search results AND home/charts/moods
            // feeds. Clearing only the search cache left the Home tab rendering the
            // previous source's content after a switch.
            searchState.musicSearchManager.clearCacheForMusicSourceChange()
            searchState.clearExploreCache()
            searchState.clearSearch()
        }
        .onChange(of: lyricsOverlayEnabled) { _, newValue in
            // 🖥 Keep the desktop lyrics overlay in sync with the setting
            LyricsOverlayController.shared.setVisible(newValue)
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
    private var hotkeyCard: some View {
        let binding = Binding<HotkeyModifier>(
            get: { HotkeyModifier(rawValue: storedHotkeyModifierRawValue) ?? .option },
            set: { newValue in
                storedHotkeyModifierRawValue = newValue.rawValue
                hotkeyManager.updateHotkey(modifier: newValue)
            }
        )

        let currentModifier = binding.wrappedValue

        settingsCard(spacing: 8) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Global Hotkey")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }

            Text("Choose the modifier key used with Space to show or hide Izzy")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Picker("Hotkey Modifier", selection: binding) {
                ForEach(HotkeyModifier.allCases) { modifier in
                    Text("\(modifier.symbol) \(modifier.displayName)")
                        .font(.system(size: 14))
                        .tag(modifier)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Text("Shortcut: \(currentModifier.symbol) \(currentModifier.displayName) + Space")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if currentModifier == .command {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("Command + Space is used by Spotlight. You may need to change Spotlight shortcuts in System Settings -> Keyboard -> Keyboard Shortcuts.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }

            if let failedModifier = hotkeyManager.lastFailedModifier {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("We couldn't enable \(failedModifier.symbol) \(failedModifier.displayName) + Space (error \(hotkeyManager.lastRegistrationStatus)).")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Text("macOS may already be using this shortcut. Izzy reverted to \(currentModifier.symbol) \(currentModifier.displayName) + Space.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
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
    private var windowPositionCard: some View {
        settingsCard(spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Window Position")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }

            Text("Control where the app window appears on your screen")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button("Center Window") {
                windowManager?.centerWindowPosition()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Use the drag handle at the top of the window to reposition it. The app will remember its position when you toggle it with the hotkey.")
                .font(.system(size: 11))
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
                            searchState.clearExploreCache()
                            print("🔄 Music source changed from '\(oldSource)' to '\(newSource.rawValue)' - caches cleared")
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

            if MusicSource(rawValue: musicSource) == .tidal {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(MusicSource.tidal.color)
                        .font(.system(size: 12))

                    Text("Tidal integration provides access to Hi-Res lossless audio quality (up to 24-bit/192kHz FLAC) and Dolby Atmos.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                TidalSettingsSection()
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Provider Switch Button Mode Setting
            HStack {
                Image(systemName: "hand.tap")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))
                
                Text("Quick Switch Mode")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
            }
            
            Text("Choose how the provider switch button in the top-left corner works")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Picker("Switch Mode", selection: Binding(
                get: { UserDefaults.standard.string(forKey: "providerSwitchMode") ?? "dropdown" },
                set: { UserDefaults.standard.set($0, forKey: "providerSwitchMode") }
            )) {
                Text("Dropdown Menu")
                    .tag("dropdown")
                
                Text("Click to Cycle")
                    .tag("click")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Text(UserDefaults.standard.string(forKey: "providerSwitchMode") == "click" 
                ? "Click the button to cycle through providers one by one" 
                : "Click to open a menu and select any provider directly")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var playbackCard: some View {
        settingsCard {
            HStack {
                Image(systemName: "infinity")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Playback")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }

            // 📻 Autoplay Radio
            HStack {
                Text("Autoplay Radio")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle("", isOn: $autoplayRadioEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle())
            }

            Text("When the queue ends, keep playing similar tracks")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // 🖥 Desktop Lyrics
            HStack {
                Text("Desktop Lyrics")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle("", isOn: $lyricsOverlayEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle())
            }

            Text("Show a floating lyrics overlay on your desktop")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 4)

            // ⏩ Playback Speed
            HStack {
                Text("Playback Speed")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }

            Picker(
                "Playback Speed",
                selection: Binding(
                    get: { playback.playbackSpeed },
                    set: { newValue in
                        playback.setPlaybackSpeed(newValue)
                    }
                )
            ) {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    Text(speed == speed.rounded() ? "\(Int(speed))×" : "\(speed)×")
                        .font(.system(size: 14))
                        .tag(speed)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Speeds up or slows down playback without changing the pitch")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var integrationsCard: some View {
        settingsCard {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .medium))

                Text("Integrations")
                    .font(.system(size: 14, weight: .medium))

                Spacer()
            }

            // 🎮 Discord Rich Presence
            HStack {
                Text("Discord Rich Presence")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle("", isOn: $discordRichPresenceEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle())
            }

            Text("Show what you're playing on your Discord profile")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()
                .padding(.vertical, 4)

            // 🔐 Last.fm scrobbling
            LastFMSettingsSection()
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

            HStack {
                Text("Show AI Search Tab")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle("", isOn: $showAISearch)
                    .labelsHidden()
            }
            .padding(.bottom, 4)

            Text("Uses Apple Intelligence for on-device natural language understanding. No API key needed.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if #available(macOS 26.0, *) {
                HStack {
                    Text("Apple Intelligence")
                        .font(.system(size: 14, weight: .medium))

                    Spacer()

                    if FoundationModelsService.shared.isAvailable {
                        Label("Available", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Available", systemImage: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }

                HStack {
                    Text("Disable AI features")
                        .font(.system(size: 14, weight: .medium))

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { FoundationModelsService.shared.isDisabledByUser },
                        set: { FoundationModelsService.shared.isDisabledByUser = $0 }
                    ))
                    .labelsHidden()
                }
            } else {
                HStack {
                    Label("Requires macOS 26 or later", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                }
            }
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
    .environmentObject(GlobalHotkeyManager())
        .frame(width: 600, height: 400)
        .padding()
        .background(Color.black.opacity(0.1))
}


// MARK: - Tidal Settings Section

/// Streaming quality, Dolby Atmos and API endpoint options for the Tidal source.
struct TidalSettingsSection: View {
    @AppStorage(TidalSettings.qualityKey) private var quality: String = TidalQualityPreference.max.rawValue
    @AppStorage(TidalSettings.dolbyAtmosKey) private var dolbyAtmos: Bool = false
    @AppStorage(TidalSettings.apiURLKey) private var apiURL: String = ""
    @AppStorage(TidalSettings.apiKeyKey) private var apiKey: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "hifispeaker")
                    .foregroundColor(MusicSource.tidal.color)
                    .font(.system(size: 14, weight: .medium))
                Text("Tidal Streaming Quality")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }

            Picker("Quality", selection: $quality) {
                ForEach(TidalQualityPreference.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("If a track is not available at the chosen quality, Izzy tries the next higher tier, then lower ones. Hi-Res masters that only exist at CD quality play as Lossless.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $dolbyAtmos) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prefer Dolby Atmos")
                        .font(.system(size: 13, weight: .medium))
                    Text("Plays the Dolby Atmos (E-AC-3 JOC) mix when Tidal has one, otherwise falls back to stereo at the quality above. Downloads are always stereo.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Custom API instance (optional)")
                    .font(.system(size: 13, weight: .medium))
                TextField("https://your-hifi-api.example.com", text: $apiURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                SecureField("API key (sent as X-API-Key, optional)", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                Text("A hifi-api compatible server tried before the built-in public instances. Required for playback when the public instances refuse /track/.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Last.fm Settings Section

/// 🔐 Scrobbling credentials and connect flow for the Last.fm integration.
struct LastFMSettingsSection: View {
    @ObservedObject private var lastFM = LastFMService.shared
    @AppStorage("lastfmScrobblingEnabled") private var scrobblingEnabled = false
    @AppStorage("lastfmApiKey") private var apiKey = ""
    @AppStorage("lastfmSecret") private var sharedSecret = ""
    @AppStorage("lastfmUsername") private var username = ""
    @AppStorage("lastfmPassword") private var password = ""
    @State private var isConnecting = false
    @State private var connectSucceeded: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.red)
                    .font(.system(size: 14, weight: .medium))

                Text("Last.fm")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                if lastFM.isAuthenticated {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }

            // 💾 Scrobbling toggle
            HStack {
                Text("Scrobbling")
                    .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle("", isOn: $scrobblingEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle())
            }

            // 🔑 API credentials (each user needs their own Last.fm API account)
            VStack(alignment: .leading, spacing: 4) {
                TextField("API key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                TextField("Shared secret", text: $sharedSecret)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12))
            }

            // 🔌 Connect / Sign Out
            HStack(spacing: 8) {
                Button(isConnecting ? "Connecting..." : "Connect") {
                    connect()
                }
                .disabled(isConnecting || !canConnect)

                if lastFM.isAuthenticated {
                    Button("Sign Out") {
                        LastFMService.shared.signOut()
                        connectSucceeded = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            // ✅ / ❌ Connect feedback
            if let connectSucceeded {
                HStack(spacing: 6) {
                    Image(systemName: connectSucceeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundColor(connectSucceeded ? .green : .red)
                        .font(.system(size: 11))
                    Text(connectSucceeded ? "Connected to Last.fm" : "Couldn't connect — check your credentials and API key")
                        .font(.system(size: 11))
                        .foregroundColor(connectSucceeded ? .green : .red)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                    .font(.system(size: 11))

                Text("Scrobbling needs your own Last.fm API account — create one at last.fm/api, then paste the API key and shared secret here.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var canConnect: Bool {
        !apiKey.isEmpty && !sharedSecret.isEmpty
    }

    private func connect() {
        isConnecting = true
        connectSucceeded = nil
        Task {
            let success = await LastFMService.shared.authenticate()
            await MainActor.run {
                isConnecting = false
                connectSucceeded = success
            }
        }
    }
}
