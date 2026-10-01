//
//  M3UService.swift
//  Izzy
//
//  Playlist import/export in extended M3U format. Local files export as real
//  URIs; streamed tracks carry their source + id in an #IZZY-META comment so a
//  future importer can re-resolve them inside Izzy.
//

import Foundation

struct M3UEntry {
    var title: String
    var artist: String
    var duration: Double?
    var localFileURL: URL?
    var izzyID: String?
    var izzySource: String?
}

enum M3UService {

    private static var playlistsDir: URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let dir = downloads.appendingPathComponent("Izzy Music/Playlists", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Export

    static func export(playlist: Playlist) throws -> URL {
        var lines = ["#EXTM3U", "#PLAYLIST:\(playlist.name)"]
        for song in playlist.songs {
            let artist = song.artist ?? "Unknown Artist"
            let seconds = Int(song.duration ?? 0)
            let source = song.musicSource
            lines.append("#EXTINF:\(seconds),\(artist) - \(song.title)")
            if let source {
                lines.append("#IZZY-META: source=\(source);id=\(song.videoId)")
            }
            if source == "local", let url = URL(string: song.videoId), url.isFileURL {
                lines.append(url.path)
            } else {
                lines.append("\(song.title) - \(artist)")
            }
        }

        let safeName = playlist.name
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let target = playlistsDir.appendingPathComponent("\(safeName.isEmpty ? "Playlist" : safeName).m3u8")
        try lines.joined(separator: "\n").data(using: .utf8)?.write(to: target, options: .atomic)
        return target
    }

    // MARK: - Import

    static func parse(url: URL) throws -> [M3UEntry] {
        let raw = try String(contentsOf: url, encoding: .utf8)
        var entries: [M3UEntry] = []
        var pendingDuration: Double?
        var pendingMeta: (source: String?, id: String?)?

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#EXTINF:") {
                // #EXTINF:<dur>,<artist> - <title>   (artist part optional)
                let payload = trimmed.dropFirst("#EXTINF:".count)
                let parts = payload.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
                if let dur = parts.first, let seconds = Double(dur.trimmingCharacters(in: .whitespaces)) {
                    pendingDuration = seconds
                }
                var title = parts.count > 1 ? String(parts[1]) : "Unknown Title"
                var artist = "Unknown Artist"
                if let dashRange = title.range(of: " - ") {
                    artist = String(title[..<dashRange.lowerBound])
                    title = String(title[dashRange.upperBound...])
                }
                entries.append(M3UEntry(title: title.trimmingCharacters(in: .whitespaces),
                                        artist: artist.trimmingCharacters(in: .whitespaces),
                                        duration: nil, localFileURL: nil,
                                        izzyID: nil, izzySource: nil))
            } else if trimmed.hasPrefix("#IZZY-META:") {
                // #IZZY-META: source=tidal;id=12345
                let payload = trimmed.dropFirst("#IZZY-META:".count).trimmingCharacters(in: .whitespaces)
                var source: String?
                var id: String?
                for pair in payload.split(separator: ";") {
                    let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    if kv.count == 2 {
                        if kv[0] == "source" { source = kv[1] }
                        if kv[0] == "id" { id = kv[1] }
                    }
                }
                pendingMeta = (source, id)
            } else if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            } else {
                // A URI/path line belongs to the last EXTINF entry.
                var resolved: URL?
                if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                    resolved = URL(string: trimmed)
                } else if trimmed.hasPrefix("/") {
                    resolved = URL(fileURLWithPath: trimmed)
                } else {
                    resolved = URL(fileURLWithPath: trimmed, relativeTo: url.deletingLastPathComponent())
                }
                if entries.isEmpty {
                    entries.append(M3UEntry(title: url.deletingPathExtension().lastPathComponent,
                                            artist: "Unknown Artist", duration: nil,
                                            localFileURL: nil, izzyID: nil, izzySource: nil))
                }
                if let fileURL = resolved, fileURL.isFileURL,
                   FileManager.default.fileExists(atPath: fileURL.path) {
                    entries[entries.count - 1].localFileURL = fileURL
                }
                entries[entries.count - 1].duration = pendingDuration
                entries[entries.count - 1].izzySource = pendingMeta?.source
                entries[entries.count - 1].izzyID = pendingMeta?.id
                pendingDuration = nil
                pendingMeta = nil
            }
        }
        return entries
    }

    /// Convert imported entries into FavoriteSongs playable inside Izzy:
    /// local files become "local" tracks; streamed entries keep their original
    /// source+id when known, otherwise fall back to the current music source
    /// so the search layer can re-resolve them by title.
    static func favoriteSongs(from entries: [M3UEntry]) -> [FavoriteSong] {
        entries.map { entry in
            let isLocal = entry.localFileURL != nil
            let videoId = entry.localFileURL?.absoluteString ?? entry.izzyID ?? entry.title
            let source = isLocal ? "local" : (entry.izzySource ?? "local")
            let result = SearchResult(
                type: .song,
                title: entry.title,
                artist: entry.artist,
                thumbnailURL: nil,
                duration: entry.duration,
                videoId: videoId,
                musicSource: source
            )
            return FavoriteSong(from: result, musicSource: source)
        }
    }
}
