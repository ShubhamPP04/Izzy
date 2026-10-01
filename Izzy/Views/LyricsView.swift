//
//  LyricsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 23/02/26.
//

import SwiftUI

// MARK: - Lyrics View

/// Inline panel displaying lyrics for the current track, synced with playback timestamps.
struct LyricsView: View {
    @ObservedObject var playbackManager: PlaybackManager
    @ObservedObject private var overlayController = LyricsOverlayController.shared
    
    @State private var lyrics: LyricsData?
    @State private var isLoading = false
    @State private var lastLoadedVideoId: String?
    @State private var currentLineIndex: Int = 0
    
    private let pythonService = PythonServiceManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider().opacity(0.3)
            
            // Content
            contentView
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        )
        .onChange(of: playbackManager.currentTrack?.videoId) { _, newVideoId in
            if let videoId = newVideoId, videoId != lastLoadedVideoId {
                Task { await loadLyrics(for: videoId) }
            }
        }
        .onAppear {
            if let videoId = playbackManager.currentTrack?.videoId, videoId != lastLoadedVideoId {
                Task { await loadLyrics(for: videoId) }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Lyrics")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Show sync indicator
                if let lyrics = lyrics, lyrics.isSynced {
                    Text("SYNCED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            
            Spacer()
            
            // 🖥️ Desktop lyrics overlay toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    LyricsOverlayController.shared.setVisible(!overlayController.isVisible)
                }
            }) {
                Image(systemName: desktopLyricsIcon)
                    .font(.system(size: 14))
                    .foregroundColor(overlayController.isVisible ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Desktop lyrics")
            .help("Desktop lyrics")
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    playbackManager.showLyrics = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // 🎛️ The "lyrics" symbol ships with newer macOS; fall back gracefully.
    private var desktopLyricsIcon: String {
        let on = overlayController.isVisible
        if #available(macOS 15.0, *) {
            return on ? "lyrics" : "lyrics"
        }
        return on ? "text.bubble.fill" : "text.bubble"
    }
    
    // MARK: - Content Router
    
    @ViewBuilder
    private var contentView: some View {
        if playbackManager.currentTrack == nil {
            emptyStateView(icon: "play.circle", title: "No Song Playing", subtitle: "Play a song to view\nits lyrics here.")
        } else if isLoading {
            loadingView
        } else if let lyrics = lyrics, lyrics.isAvailable {
            if lyrics.isSynced, let syncedLines = lyrics.syncedLyrics {
                syncedLyricsView(syncedLines, source: lyrics.source)
            } else {
                plainLyricsView(lyrics)
            }
        } else {
            emptyStateView(icon: "music.note", title: "No Lyrics Available", subtitle: "Lyrics aren't available\nfor this song.")
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Finding lyrics...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Synced Lyrics (timestamp-based)
    
    private func syncedLyricsView(_ lines: [SyncedLine], source: String?) -> some View {
        ScrollViewReader { scrollProxy in
            // 🎤 ~20fps while playing so line changes land exactly on time and
            // the karaoke fill is continuous — driven by the interpolated
            // clock, not the 1s battery-saving observer tick. Paused lyrics
            // tick at 1fps (nothing moves).
            TimelineView(.periodic(from: .now, by: playbackManager.playbackState.isPlaying ? 0.05 : 0.5)) { _ in
                let smoothTime = playbackManager.interpolatedTime()
                let index = Self.lineIndex(at: smoothTime, lines: lines)
                let progress = Self.lineProgress(at: smoothTime, lines: lines, index: index)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        trackHeader

                        Divider().padding(.horizontal, 16).opacity(0.3)

                        ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                            Group {
                                if i == index {
                                    // 🎤 Current line gets the progressive karaoke fill
                                    karaokeFilledLine(line.text, progress: progress)
                                } else {
                                    Text(line.text.isEmpty ? " " : line.text)
                                }
                            }
                            .font(.system(
                                size: i == index ? 16 : 14,
                                weight: i == index ? .bold : .medium
                            ))
                            .lineSpacing(4)
                            .foregroundColor(syncedLineColor(for: i, current: index))
                            .scaleEffect(i == index ? 1.02 : 1.0, anchor: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(i)
                            .animation(.easeInOut(duration: 0.25), value: index)
                        }

                        sourceFooter(source)

                        Spacer(minLength: 20)
                    }
                }
                .onChange(of: index, initial: true) { _, newIndex in
                    // initial: true — opening the panel mid-song must land on
                    // the current line immediately, not line 0.
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Smooth Sync Helpers

    /// Last line whose timestamp <= the (interpolated) playback time.
    private static func lineIndex(at time: Double, lines: [SyncedLine]) -> Int {
        var index = 0
        for (i, line) in lines.enumerated() {
            if line.time <= time { index = i } else { break }
        }
        return index
    }

    /// Sung fraction of the current line, linear between its timestamp and the
    /// next one's (the last line gets a 4s window).
    private static func lineProgress(at time: Double, lines: [SyncedLine], index: Int) -> Double {
        let start = lines[index].time
        let end = index + 1 < lines.count ? lines[index + 1].time : start + 4
        let span = max(end - start, 0.25)
        return min(max((time - start) / span, 0), 1)
    }
    
    // MARK: - Karaoke Fill

    /// 🎤 Renders the line twice: a dim base plus a bright overlay masked to the
    /// sung fraction of the line width. The fill is animated linearly between
    /// time ticks so it looks continuous without per-frame updates.
    private func karaokeFilledLine(_ text: String, progress: Double) -> some View {
        let displayText = text.isEmpty ? " " : text
        return ZStack(alignment: .leading) {
            Text(displayText)
                .foregroundColor(.secondary.opacity(0.35))

            Text(displayText)
                .foregroundColor(.primary)
                .mask(
                    Rectangle()
                        .scaleEffect(x: progress, y: 1, anchor: .leading)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plain Lyrics (estimated sync fallback)
    
    private func plainLyricsView(_ lyrics: LyricsData) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    trackHeader
                    
                    Divider().padding(.horizontal, 16).opacity(0.3)
                    
                    let lines = lyrics.lines
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 14, weight: index == currentLineIndex ? .bold : .medium))
                            .lineSpacing(4)
                            .foregroundColor(plainLineColor(for: index, total: lines.count))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                            .animation(.easeInOut(duration: 0.3), value: currentLineIndex)
                    }
                    
                    sourceFooter(lyrics.source)
                    
                    Spacer(minLength: 20)
                }
            }
            .onChange(of: playbackManager.currentTime) { _, _ in
                updateEstimatedLine(lines: lyrics.lines, scrollProxy: scrollProxy)
            }
        }
    }
    
    // MARK: - Shared Sub-views
    
    private var trackHeader: some View {
        Group {
            if let track = playbackManager.currentTrack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(track.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
        }
    }
    
    private func sourceFooter(_ source: String?) -> some View {
        Group {
            if let source = source {
                VStack(spacing: 0) {
                    Divider().padding(.horizontal, 16).padding(.top, 12)
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
        }
    }
    
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Synced Line Highlighting
    
    private func syncedLineColor(for index: Int, current: Int) -> Color {
        if index == current {
            return .primary
        } else if index < current {
            return .secondary.opacity(0.45)
        } else {
            return .secondary.opacity(0.3)
        }
    }
    
    // MARK: - Estimated Line Highlighting (plain lyrics fallback)
    
    private func updateEstimatedLine(lines: [String], scrollProxy: ScrollViewProxy) {
        guard playbackManager.duration > 0 else { return }
        
        let progress = playbackManager.currentTime / playbackManager.duration
        let nonEmptyLines = lines.enumerated().filter { !$0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !nonEmptyLines.isEmpty else { return }
        
        let estimatedIndex = Int(progress * Double(nonEmptyLines.count))
        let clampedIndex = max(0, min(estimatedIndex, nonEmptyLines.count - 1))
        let newLineIndex = nonEmptyLines[clampedIndex].offset
        
        if newLineIndex != currentLineIndex {
            currentLineIndex = newLineIndex
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy.scrollTo(newLineIndex, anchor: .center)
            }
        }
    }
    
    private func plainLineColor(for index: Int, total: Int) -> Color {
        if index == currentLineIndex {
            return .primary
        } else if index < currentLineIndex {
            return .secondary.opacity(0.5)
        } else {
            return .secondary.opacity(0.35)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadLyrics(for videoId: String) async {
        await MainActor.run {
            isLoading = true
            lastLoadedVideoId = videoId
            currentLineIndex = 0
        }
        
        let trackTitle = playbackManager.currentTrack?.title
        let trackArtist = playbackManager.currentTrack?.artist
        
        do {
            let fetchedLyrics = try await pythonService.getLyrics(
                videoId: videoId,
                title: trackTitle,
                artist: trackArtist
            )
            await MainActor.run {
                if playbackManager.currentTrack?.videoId == videoId {
                    lyrics = fetchedLyrics
                }
                isLoading = false
            }
        } catch {
            print("❌ Failed to load lyrics: \(error.localizedDescription)")
            await MainActor.run {
                lyrics = .unavailable
                isLoading = false
            }
        }
    }
}
