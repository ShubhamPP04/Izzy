//
//  MusicSearchTool.swift
//  Izzy
//
//  Tool that lets Apple Intelligence search the music catalog via PythonServiceManager.
//  Adapted from kaset (https://github.com/sozercan/kaset)
//

import Foundation
import FoundationModels

@available(macOS 26.0, *)
struct MusicSearchTool: Tool {
    private let pythonService = PythonServiceManager.shared

    let name = "searchMusic"

    let description = """
    Searches the music catalog for songs, albums, artists, and playlists.
    Use this tool to find real music content before suggesting playback or queuing.
    Returns formatted results with IDs that can be used for playback.
    """

    @Generable
    struct Arguments {
        @Guide(description: "The search query (song title, artist name, album, etc.)")
        let query: String

        @Guide(description: "Optional filter: 'songs', 'albums', 'artists', 'playlists', or 'all' for no filter")
        let filter: String
    }

    typealias Output = String

    func call(arguments: Arguments) async throws -> String {
        do {
            try pythonService.ensureServiceRunning()
            let response = try await pythonService.searchMusic(query: arguments.query, limit: 10)

            var results: [String] = []
            let includeAll = arguments.filter.isEmpty || arguments.filter == "all"

            if includeAll || arguments.filter == "songs" {
                for song in response.songs.prefix(5) {
                    results.append("SONG: \"\(song.title)\" by \(song.artist ?? "Unknown") [videoId: \(song.videoId ?? "")]")
                }
            }

            if includeAll || arguments.filter == "albums" {
                for album in response.albums.prefix(3) {
                    results.append("ALBUM: \"\(album.title)\" [browseId: \(album.browseId ?? album.id)]")
                }
            }

            if includeAll || arguments.filter == "artists" {
                for artist in response.artists.prefix(3) {
                    results.append("ARTIST: \(artist.title) [browseId: \(artist.browseId ?? artist.id)]")
                }
            }

            if includeAll || arguments.filter == "playlists" {
                for playlist in response.playlists.prefix(3) {
                    results.append("PLAYLIST: \"\(playlist.title)\" [id: \(playlist.id)]")
                }
            }

            if results.isEmpty {
                return "No results found for '\(arguments.query)'"
            }

            return """
            Search results for '\(arguments.query)':
            \(results.joined(separator: "\n"))
            """
        } catch {
            return "Search failed for '\(arguments.query)': \(error.localizedDescription)"
        }
    }
}
