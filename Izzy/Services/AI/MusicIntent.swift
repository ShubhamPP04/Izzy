//
//  MusicIntent.swift
//  Izzy
//
//  On-device AI generated struct for parsed music commands.
//  Ported from kaset (https://github.com/sozercan/kaset)
//

import Foundation
import FoundationModels

@available(macOS 26.0, *)
@Generable
struct MusicIntent {
    @Guide(description: "The action to perform: play, queue, shuffle, like, dislike, skip, previous, pause, resume, search")
    let action: MusicAction

    @Guide(description: "The search query, song title, or artist name. Empty for actions like skip, pause, resume.")
    let query: String

    @Guide(description: "The scope for shuffle: all, library, likes, or empty for single song actions.")
    let shuffleScope: String

    @Guide(description: "Artist name if mentioned (e.g., 'Rolling Stones'). Empty if not specified.")
    let artist: String

    @Guide(description: "Genre if mentioned (rock, jazz, hip-hop, classical, electronic, pop, country, r&b, indie, metal, folk, latin, k-pop). Empty if not specified.")
    let genre: String

    @Guide(description: "Mood if mentioned (upbeat, chill, sad, happy, energetic, relaxing, melancholic, romantic, aggressive, peaceful, groovy, dark). Empty if not specified.")
    let mood: String

    @Guide(description: "Era if mentioned. Use decade format: '1960s', '1970s', '1980s', '1990s', '2000s', '2010s', '2020s'. Or 'classic' for oldies. Empty if not specified.")
    let era: String

    @Guide(description: "Version type if mentioned (acoustic, live, remix, instrumental, cover, unplugged). Empty if not specified.")
    let version: String

    @Guide(description: "Activity if mentioned (workout, study, sleep, party, driving, cooking, focus, running, yoga). Empty if not specified.")
    let activity: String

    func buildSearchQuery() -> String {
        if !query.isEmpty, artist.isEmpty, genre.isEmpty, mood.isEmpty, era.isEmpty {
            return query
        }

        var parts: [String] = []
        var hasHits = false
        let wantsHits = queryWantsHits()

        if !artist.isEmpty {
            (parts, hasHits) = buildArtistQuery(wantsHits: wantsHits)
        } else if !era.isEmpty {
            (parts, hasHits) = buildEraQuery()
        } else {
            parts = buildGenericQuery()
        }

        parts = appendAdditionalComponents(to: parts)

        let hasMusic = parts.contains { $0.lowercased() == "music" }
        if !parts.isEmpty, !hasHits, !hasMusic {
            parts.append("songs")
        }

        return parts.joined(separator: " ")
    }

    private func queryWantsHits() -> Bool {
        let queryLower = query.lowercased()
        return queryLower.contains("hit") || queryLower.contains("best") ||
            queryLower.contains("greatest") || queryLower.contains("top")
    }

    private func buildArtistQuery(wantsHits: Bool) -> ([String], Bool) {
        var parts: [String] = [artist]
        var hasHits = false

        if !era.isEmpty { parts.append(normalizeEra(era)) }
        if wantsHits { parts.append("greatest hits"); hasHits = true }
        if !genre.isEmpty { parts.append(genre) }
        if !mood.isEmpty { parts.append(mood) }

        return (parts, hasHits)
    }

    private func buildEraQuery() -> ([String], Bool) {
        var parts: [String] = [normalizeEra(era)]

        if !mood.isEmpty {
            parts.append(moodToGenre(mood))
        } else if !genre.isEmpty {
            parts.append(genre)
        }

        parts.append("hits")
        return (parts, true)
    }

    private func buildGenericQuery() -> [String] {
        var parts: [String] = []
        if !genre.isEmpty { parts.append(genre) }
        if !mood.isEmpty { parts.append(mood) }

        if genre.isEmpty, !mood.isEmpty, artist.isEmpty, activity.isEmpty {
            parts.append("music")
        }

        return parts
    }

    private func appendAdditionalComponents(to parts: [String]) -> [String] {
        var result = parts

        if !query.isEmpty {
            let cleanQuery = cleanQueryForAppending(query)
            if !cleanQuery.isEmpty, cleanQuery.lowercased() != artist.lowercased() {
                result.append(cleanQuery)
            }
        }

        if !version.isEmpty { result.append(version) }
        if !activity.isEmpty, result.isEmpty { result.append("\(activity) music") }

        return result
    }

    private func cleanQueryForAppending(_ query: String) -> String {
        let words = query.lowercased().split(separator: " ")
        let skipWords: Set<String> = [
            "play", "some", "the", "a", "an", "me", "from", "of",
            "songs", "music", "tracks", "hits", "hit", "best", "greatest", "top",
        ]
        let filtered = words.filter { !skipWords.contains(String($0)) }
        return filtered.joined(separator: " ")
    }

    private func normalizeEra(_ era: String) -> String {
        let lowered = era.lowercased()
        if lowered.contains("1960") { return "60s" }
        if lowered.contains("1970") { return "70s" }
        if lowered.contains("1980") { return "80s" }
        if lowered.contains("1990") { return "90s" }
        if lowered.contains("2000") { return "2000s" }
        if lowered.contains("2010") { return "2010s" }
        if lowered.contains("2020") { return "2020s" }
        return era
    }

    private func moodToGenre(_ mood: String) -> String {
        switch mood.lowercased() {
        case "energetic", "upbeat", "happy": return "dance"
        case "chill", "relaxing", "peaceful", "mellow": return "chill"
        case "sad", "melancholic": return "ballads"
        case "romantic": return "love"
        case "aggressive", "intense": return "rock"
        case "groovy", "funky": return "funk"
        case "dark": return "alternative"
        default: return mood
        }
    }

    func queryDescription() -> String {
        var parts: [String] = []

        let wantsHits = query.lowercased().contains("hit") || query.lowercased().contains("best") ||
            query.lowercased().contains("greatest") || query.lowercased().contains("top")

        if !mood.isEmpty { parts.append(mood) }
        if !genre.isEmpty { parts.append(genre) }
        if wantsHits { parts.append("hits") }
        if !artist.isEmpty { parts.append("by \(artist)") }
        if !era.isEmpty { parts.append("from the \(era)") }
        if !version.isEmpty { parts.append("(\(version))") }
        if !activity.isEmpty { parts.append("for \(activity)") }

        if parts.isEmpty { return query }
        return parts.joined(separator: " ")
    }
}

@available(macOS 26.0, *)
@Generable
enum MusicAction: String, CaseIterable {
    case play
    case queue
    case shuffle
    case like
    case dislike
    case skip
    case previous
    case pause
    case resume
    case search
}
