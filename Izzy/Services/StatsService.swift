//
//  StatsService.swift
//  Izzy
//
//  Listening stats: accumulates per-track play counts and listened seconds,
//  persisted to Application Support as JSON. All accumulation is Combine-driven
//  from PlaybackManager, throttled so nothing touches disk per tick.
//

import AppKit
import Combine
import Foundation

struct TrackStat: Codable, Identifiable {
    let id: String
    var title: String
    var artist: String
    var musicSource: String
    var playCount: Int
    var secondsListened: Double
    var lastPlayed: Date
}

final class StatsService: ObservableObject {
    static let shared = StatsService()

    /// Sorted by secondsListened (descending) after every mutation.
    @Published private(set) var stats: [TrackStat] = []

    private var statsByID: [String: TrackStat] = [:]
    private var isLoaded = false
    private var saveCutoff = Date.distantPast
    private var needsSave = false

    // Accumulation anchors
    private var lastTickTime: Double?
    private var lastTickWallClock = Date()
    private var activeTrackID: String?
    private var cancellables = Set<AnyCancellable>()

    private let queue = DispatchQueue(label: "izzy.stats", qos: .utility)

    private static var storeURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Izzy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }

    private init() {
        load()

        // 🔋 Accumulate listened seconds from the player's time ticks.
        PlaybackManager.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.accumulate(time: time)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .izzyTrackChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let track = note.userInfo?["track"] as? Track else { return }
                self?.handleTrackChanged(track)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.saveIfNeeded(force: true)
        }
    }

    private func handleTrackChanged(_ track: Track) {
        // A play counts once ≥30s of the track were actually listened to.
        if let activeID = activeTrackID,
           var stat = statsByID[activeID],
           stat.secondsListened > 0 {
            // playCount is bumped lazily at threshold time in accumulate();
            // nothing extra needed here beyond a save.
        }
        activeTrackID = Self.id(for: track)
        lastTickTime = nil
    }

    private static func id(for track: Track) -> String {
        "\(track.title)|\(track.artist)".lowercased()
    }

    /// Fold the newest currentTime tick into the active track's listened total.
    private func accumulate(time: Double) {
        guard playbackManager.isPlaying,
              let track = playbackManager.currentTrack else {
            lastTickTime = nil
            return
        }
        defer { lastTickTime = time; lastTickWallClock = Date() }

        let id = Self.id(for: track)
        if activeTrackID != id {
            // Seek/back-jump protection: a jump larger than 2s resets the anchor.
            lastTickTime = time
            activeTrackID = id
            return
        }
        guard let last = lastTickTime else { lastTickTime = time; return }
        let delta = time - last
        guard delta > 0, delta <= 2.0 else { return } // ignore seeks

        if statsByID[id] == nil {
            statsByID[id] = TrackStat(id: id, title: track.title, artist: track.artist,
                                      musicSource: track.musicSource ?? "unknown",
                                      playCount: 0, secondsListened: 0, lastPlayed: Date())
        }
        statsByID[id]?.secondsListened += delta
        statsByID[id]?.lastPlayed = Date()

        // A play counts after 30s listened for this track in this session.
        if let stat = statsByID[id], stat.playCount == 0, stat.secondsListened >= 30 {
            statsByID[id]?.playCount = 1
        } else if var stat = statsByID[id], stat.playCount > 0,
                  Int(stat.secondsListened) / 30 > stat.playCount {
            // Rough re-play accounting: each additional ~full listen after 30s
            statsByID[id]?.playCount = max(1, Int(stat.secondsListened) / 180) + 1
        }

        republishIfNeeded()
        saveIfNeeded()
    }

    private var playbackManager: PlaybackManager { PlaybackManager.shared }

    private var lastRepublish = Date.distantPast
    private func republishIfNeeded() {
        // 🔋 Re-publish at most once a second so list UIs don't churn per tick.
        guard Date().timeIntervalSince(lastRepublish) > 1.0 else { return }
        lastRepublish = Date()
        stats = Array(statsByID.values).sorted { $0.secondsListened > $1.secondsListened }
    }

    // MARK: - Public API

    func topTracks(limit: Int) -> [TrackStat] {
        Array(stats.prefix(limit))
    }

    func topArtists(limit: Int) -> [(name: String, seconds: Double, plays: Int)] {
        var byArtist: [String: (seconds: Double, plays: Int)] = [:]
        for stat in stats {
            let name = stat.artist.isEmpty ? "Unknown Artist" : stat.artist
            var entry = byArtist[name] ?? (0, 0)
            entry.seconds += stat.secondsListened
            entry.plays += stat.playCount
            byArtist[name] = entry
        }
        return byArtist
            .map { (name: $0.key, seconds: $0.value.seconds, plays: $0.value.plays) }
            .sorted { $0.seconds > $1.seconds }
            .prefix(limit)
            .map { $0 }
    }

    var totalSecondsListened: Double {
        stats.reduce(0) { $0 + $1.secondsListened }
    }

    var totalPlays: Int {
        stats.reduce(0) { $0 + $1.playCount }
    }

    func resetAll() {
        statsByID.removeAll()
        stats = []
        needsSave = true
        saveIfNeeded(force: true)
    }

    // MARK: - Persistence

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: Self.storeURL),
              let list = try? JSONDecoder().decode([TrackStat].self, from: data) else { return }
        for stat in list {
            statsByID[stat.id] = stat
        }
        stats = Array(statsByID.values).sorted { $0.secondsListened > $1.secondsListened }
    }

    private func saveIfNeeded(force: Bool = false) {
        needsSave = true
        let now = Date()
        guard force || now.timeIntervalSince(saveCutoff) >= 30 else { return }
        saveCutoff = now
        needsSave = false
        let list = Array(statsByID.values)
        let url = Self.storeURL
        queue.async {
            if let data = try? JSONEncoder().encode(list) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}
