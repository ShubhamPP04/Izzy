//
//  FoundationModelsPromptLibrary.swift
//  Izzy
//
//  Prompt instructions for Apple Intelligence music command parsing.
//  Adapted from kaset (https://github.com/sozercan/kaset)
//

import Foundation

@available(macOS 26.0, *)
enum FoundationModelsPromptLibrary {
    static func middleTruncate(
        _ text: String,
        targetLength: Int,
        marker: String = "\n…[truncated]…\n"
    ) -> String {
        guard targetLength > 0 else { return "" }
        guard text.count > targetLength else { return text }
        guard targetLength > marker.count else {
            return String(text.prefix(targetLength))
        }

        let remainingLength = targetLength - marker.count
        let leadingLength = (remainingLength + 1) / 2
        let trailingLength = remainingLength / 2

        return String(text.prefix(leadingLength)) + marker + String(text.suffix(trailingLength))
    }

    static func commandBarInstructions() -> String {
        """
        You are Izzy's music command parser. Return the best MusicIntent for the user's request.

        Field rules:
        - action: play, queue, shuffle, like, dislike, skip, previous, pause, resume, search
        - query: keep the important search words, including qualifiers like "hits", "greatest", and "best of"
        - artist: artist or band name only
        - genre: rock, pop, jazz, classical, hip-hop, r&b, electronic, country, folk, metal, indie, latin, k-pop
        - mood: upbeat, chill, sad, happy, energetic, relaxing, melancholic, romantic, aggressive, peaceful, groovy
        - era: use 1960s, 1970s, 1980s, 1990s, 2000s, 2010s, 2020s, or classic
        - version: acoustic, live, remix, instrumental, cover, unplugged, remastered
        - activity: workout, study, sleep, party, driving, cooking, focus, running, yoga

        Action rules:
        - skip or next -> skip
        - pause or stop -> pause
        - resume only when the user clearly wants to continue current playback
        - clear queue -> action queue with query "__clear__"
        - shuffle my queue -> action shuffle with shuffleScope "queue"

        Examples:
        - "best of queen" -> play, query "best of queen", artist "Queen"
        - "add some energetic workout music to queue" -> queue, query "energetic workout music", mood "energetic", activity "workout"
        - "chill jazz for studying" -> play, query "chill jazz for studying", genre "jazz", mood "chill", activity "study"
        - "80s synthwave" -> play, query "80s synthwave", genre "synthwave", era "1980s"

        Prefer play for requests to start music and search for explicit browse or lookup requests. Keep the query concise without dropping meaning.
        """
    }

    static func lyricsExplanationInstructions() -> String {
        """
        You explain song lyrics for Izzy. Be insightful, concrete, and accessible.
        Use the lyrics as your source of truth, avoid invented background facts,
        and keep the explanation concise.
        """
    }

    static func lyricsExplanationPrompt(trackTitle: String, artistsDisplay: String, lyrics: String) -> String {
        """
        Song: "\(trackTitle)" by \(artistsDisplay)

        Lyrics:
        \(lyrics)

        Task:
        - Identify 2-5 main themes
        - Name the overall mood
        - Explain what the song is saying in 2-4 sentences
        """
    }
}
