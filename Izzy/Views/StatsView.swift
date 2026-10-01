//
//  StatsView.swift
//  Izzy
//
//  Created by Shubham Kumar on 01/10/26.
//

import SwiftUI

// MARK: - Time Formatting

/// ⏱️ Format seconds as "Xh Ym" (falling back to "Ym" / "Zs" for short spans).
private func formatListeningTime(_ seconds: Double) -> String {
    let total = Int(max(seconds, 0))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 { return "\(hours)h \(minutes)m" }
    if minutes > 0 { return "\(minutes)m" }
    return "\(total)s"
}

// MARK: - Stats View

/// 📊 Listening statistics screen — total time, top tracks and top artists.
/// Presented as a sheet; reads everything from StatsService.shared.
struct StatsView: View {
    /// When embedded in the tab system there is no sheet to dismiss; the tab
    /// container passes a closure that returns to the previous tab.
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var statsService = StatsService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(0.3)

            // Content
            if statsService.stats.isEmpty {
                emptyStateView
            } else {
                statsContent
            }
        }
        .frame(minWidth: 440, minHeight: 520)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .shadow(radius: 5)
        )
    }

    // MARK: Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)

                Text("Listening Stats")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer()

            Button(action: {
                if let onClose { onClose() } else { dismiss() }
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

    // MARK: Content

    private var statsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                topTracksSection
                topArtistsSection
            }
            .padding(16)
        }
    }

    // MARK: Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(
                icon: "clock.fill",
                value: formatListeningTime(statsService.totalSecondsListened),
                label: "Listening Time"
            )

            Divider()
                .frame(height: 32)
                .opacity(0.3)

            summaryItem(
                icon: "music.note.list",
                value: "\(statsService.stats.count)",
                label: "Tracks"
            )

            Divider()
                .frame(height: 32)
                .opacity(0.3)

            summaryItem(
                icon: "play.circle.fill",
                value: "\(totalPlayCount)",
                label: "Total Plays"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private var totalPlayCount: Int {
        statsService.stats.reduce(0) { $0 + $1.playCount }
    }

    private func summaryItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.blue)

            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Top Tracks

    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "flame.fill", title: "Top Tracks")

            let topTracks = statsService.topTracks(limit: 10)
            if topTracks.isEmpty {
                sectionEmptyText("No plays recorded yet.")
            } else {
                ForEach(Array(topTracks.enumerated()), id: \.offset) { index, stat in
                    TrackStatRow(rank: index + 1, stat: stat)
                }
            }
        }
    }

    // MARK: Top Artists

    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "person.2.fill", title: "Top Artists")

            let topArtists = statsService.topArtists(limit: 5)
            if topArtists.isEmpty {
                sectionEmptyText("No artists to show yet.")
            } else {
                ForEach(Array(topArtists.enumerated()), id: \.offset) { index, artist in
                    ArtistStatRow(rank: index + 1, name: artist.name, seconds: artist.seconds, plays: artist.plays)
                }
            }
        }
    }

    // MARK: Shared Pieces

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    private func sectionEmptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary.opacity(0.6))
            .padding(.vertical, 6)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Stats Yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Play some songs and your listening\nstats will show up here.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Track Stat Row

/// 🎵 One ranked row in the Top Tracks list: rank, source dot, title/artist,
/// play count and formatted listening time.
private struct TrackStatRow: View {
    let rank: Int
    let stat: TrackStat

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(rank <= 3 ? .blue : .secondary)
                .frame(width: 18, alignment: .center)

            // 🔵 Source color dot
            Circle()
                .fill(MusicSource.colorForSource(stat.musicSource))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(stat.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatListeningTime(stat.secondsListened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))

                Text("\(stat.playCount) plays")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Artist Stat Row

/// 🎤 One ranked row in the Top Artists list.
private struct ArtistStatRow: View {
    let rank: Int
    let name: String
    let seconds: Double
    let plays: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(rank <= 3 ? .blue : .secondary)
                .frame(width: 18, alignment: .center)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.secondary.opacity(0.6))

            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatListeningTime(seconds))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))

                Text("\(plays) plays")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - Preview

#Preview {
    StatsView()
}
