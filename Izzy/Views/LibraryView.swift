//
//  LibraryView.swift
//  Izzy
//
//  Created by Shubham Kumar on 01/10/26.
//

import SwiftUI
import AVFoundation
import AppKit

// MARK: - Offline Library View

/// 📚 Offline Library — scans "~/Downloads/Izzy Music" recursively for audio
/// files and lists them with cheap on-demand metadata. Click a row to play it
/// straight from disk via PlaybackManager.playLocalFile.
struct LibraryView: View {
    @ObservedObject var playbackManager: PlaybackManager = PlaybackManager.shared

    // 💾 One row per local audio file discovered on disk.
    struct LocalTrack: Identifiable {
        let url: URL
        var title: String
        var artist: String?
        var duration: TimeInterval?
        var artwork: NSImage?
        var metadataLoaded: Bool = false

        var id: URL { url }
    }

    @State private var tracks: [LocalTrack] = []
    @State private var isScanning = false
    @State private var hasScanned = false

    /// 🎵 Extensions we treat as playable audio.
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "flac", "wav", "aac", "ogg"]
    /// ⏭️ Suffixes used by in-progress downloads — never list those.
    private static let inProgressExtensions: Set<String> = ["tmp", "part", "download", "crdownload"]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(0.3)

            // Content
            if tracks.isEmpty {
                emptyStateView
            } else {
                trackListView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                )
        )
        .onAppear {
            // 🚀 Kick off the first scan when the screen shows up
            if !hasScanned {
                refreshLibrary()
            }
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)

                Text("Offline Library")
                    .font(.headline)
                    .foregroundColor(.primary)

                if !tracks.isEmpty {
                    Text("\(tracks.count) songs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // 🔄 Refresh button
            Button(action: {
                refreshLibrary()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isScanning)
            .accessibilityLabel("Refresh library")
            .help("Refresh library")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Track List

    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(tracks) { track in
                    trackRow(track)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func trackRow(_ track: LocalTrack) -> some View {
        HStack(spacing: 12) {
            // 🖼️ Artwork thumbnail (placeholder until metadata lands)
            Group {
                if let artwork = track.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.25))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Song info
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(track.artist ?? "Unknown Artist")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(track.url.deletingPathExtension().pathExtension.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Spacer()

            // Duration (once metadata loads)
            if let duration = track.duration, duration.isFinite, duration > 0 {
                Text(duration.formattedDuration)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // ▶️ Play straight from disk
            playbackManager.playLocalFile(url: track.url, title: track.title, artist: track.artist)
        }
    }

    // MARK: Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        if isScanning {
            // 🔍 Scan in progress
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Scanning your downloads...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // 💤 Nothing downloaded yet
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("No Offline Songs")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Songs you download appear here — playable offline")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Scanning

    /// 🔄 Full refresh: scan the folder, then fill in metadata in chunks.
    private func refreshLibrary() {
        guard !isScanning else { return }
        isScanning = true

        Task.detached(priority: .userInitiated) {
            // 🔍 Scan off the main thread so the UI never blocks
            let urls = await Self.findAudioFiles()

            let baseRows = urls.map { url in
                LocalTrack(
                    url: url,
                    title: url.deletingPathExtension().lastPathComponent,
                    artist: nil,
                    duration: nil,
                    artwork: nil
                )
            }

            await MainActor.run {
                tracks = baseRows
                isScanning = false
                hasScanned = true
            }

            // 🏷️ Load metadata in small chunks so rows fill in progressively
            var index = 0
            while index < urls.count {
                let chunk = Array(urls[index..<min(index + 8, urls.count)])
                let loadedRows = await Self.loadMetadata(for: chunk)
                let offset = index
                await MainActor.run {
                    for (i, row) in loadedRows.enumerated() where offset + i < tracks.count {
                        tracks[offset + i] = row
                    }
                }
                index += 8
            }
        }
    }

    /// 🔍 Recursively find audio files under "~/Downloads/Izzy Music",
    /// skipping hidden files and in-progress downloads. Never touches the
    /// main thread — callers await it from a detached task.
    private static func findAudioFiles() async -> [URL] {
        let fileManager = FileManager.default
        guard let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return []
        }
        let root = downloads.appendingPathComponent("Izzy Music", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }

        var results: [URL] = []
        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()

            // ⏭️ Skip anything still downloading (and non-audio files)
            guard audioExtensions.contains(ext), !inProgressExtensions.contains(ext) else { continue }

            // 🗂️ Only regular files make the cut
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), values.isRegularFile == true {
                results.append(fileURL)
            }
        }

        // 🔤 Alphabetical, Finder-style
        return results.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// 🏷️ Load cheap metadata (title/artist/duration/artwork) for a chunk of
    /// files with the async AVFoundation API. Fails soft per file.
    private static func loadMetadata(for urls: [URL]) async -> [LocalTrack] {
        var rows: [LocalTrack] = []

        for url in urls {
            var row = LocalTrack(
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                artist: nil,
                duration: nil,
                artwork: nil
            )

            do {
                let asset = AVURLAsset(url: url)
                let metadata = try await asset.load(.commonMetadata)

                var title: String?
                var artist: String?
                var artworkData: Data?

                for item in metadata {
                    switch item.commonKey {
                    case .commonKeyTitle?:
                        title = try? await item.load(.stringValue)
                    case .commonKeyArtist?:
                        artist = try? await item.load(.stringValue)
                    case .commonKeyArtwork?:
                        artworkData = try? await item.load(.dataValue)
                    default:
                        break
                    }
                }

                // ✅ Only override the filename-derived title with something real
                if let title = title, !title.isEmpty {
                    row.title = title
                }
                row.artist = artist

                if let duration = try? await asset.load(.duration), duration.isNumeric, duration.seconds.isFinite {
                    row.duration = duration.seconds
                }

                if let artworkData = artworkData {
                    row.artwork = NSImage(data: artworkData)
                }
            } catch {
                // 🤷 Fail soft — keep the filename-derived row
                print("⚠️ Metadata failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }

            row.metadataLoaded = true
            rows.append(row)
        }

        return rows
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
}
