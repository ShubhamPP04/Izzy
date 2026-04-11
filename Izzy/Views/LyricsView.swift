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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    trackHeader
                    
                    Divider().padding(.horizontal, 16).opacity(0.3)
                    
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.system(
                                size: index == currentLineIndex ? 16 : 14,
                                weight: index == currentLineIndex ? .bold : .medium
                            ))
                            .lineSpacing(4)
                            .foregroundColor(syncedLineColor(for: index))
                            .scaleEffect(index == currentLineIndex ? 1.02 : 1.0, anchor: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(index)
                            .animation(.easeInOut(duration: 0.25), value: currentLineIndex)
                    }
                    
                    sourceFooter(source)
                    
                    Spacer(minLength: 20)
                }
            }
            .onChange(of: playbackManager.currentTime) { _, newTime in
                updateSyncedLine(lines: lines, currentTime: newTime, scrollProxy: scrollProxy)
            }
        }
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
    
    /// Find the correct line based on actual timestamps.
    private func updateSyncedLine(lines: [SyncedLine], currentTime: Double, scrollProxy: ScrollViewProxy) {
        // Binary-search style: find the last line whose time <= currentTime
        var newIndex = 0
        for (i, line) in lines.enumerated() {
            if line.time <= currentTime {
                newIndex = i
            } else {
                break
            }
        }
        
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollProxy.scrollTo(newIndex, anchor: .center)
            }
        }
    }
    
    private func syncedLineColor(for index: Int) -> Color {
        if index == currentLineIndex {
            return .primary
        } else if index < currentLineIndex {
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
