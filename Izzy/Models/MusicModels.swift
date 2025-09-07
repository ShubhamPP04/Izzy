//
//  MusicModels.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation

// MARK: - Music Sources

enum MusicSource: String, CaseIterable, Codable {
    case youtubeMusic = "youtube_music"
    case jioSaavn = "jiosaavn"
    
    var displayName: String {
        switch self {
        case .youtubeMusic: return "YouTube Music"
        case .jioSaavn: return "JioSaavn"
        }
    }
    
    var icon: String {
        switch self {
        case .youtubeMusic: return "play.circle.fill"
        case .jioSaavn: return "music.note.list"
        }
    }
}

// MARK: - Search Result Types

enum SearchResultType: String, CaseIterable, Codable {
    case song = "songs"
    case album = "albums"
    case artist = "artists"
    case playlist = "playlists"
    case video = "videos"
    
    var displayName: String {
        switch self {
        case .song: return "Songs"
        case .album: return "Albums"
        case .artist: return "Artists"
        case .playlist: return "Playlists"
        case .video: return "Videos"
        }
    }
}

// MARK: - Base Search Result

struct SearchResult: Identifiable, Codable {
    let id: String
    let type: SearchResultType
    let title: String
    let artist: String?
    let thumbnailURL: String?
    let duration: TimeInterval?
    let explicit: Bool
    let videoId: String?
    let browseId: String?
    let year: String?
    let playCount: String?
    
    init(id: String = UUID().uuidString, 
         type: SearchResultType,
         title: String,
         artist: String? = nil,
         thumbnailURL: String? = nil,
         duration: TimeInterval? = nil,
         explicit: Bool = false,
         videoId: String? = nil,
         browseId: String? = nil,
         year: String? = nil,
         playCount: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.artist = artist
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.explicit = explicit
        self.videoId = videoId
        self.browseId = browseId
        self.year = year
        self.playCount = playCount
    }
}

// MARK: - Grouped Search Results

struct MusicSearchResults: Codable {
    var songs: [SearchResult] = []
    var albums: [SearchResult] = []
    var artists: [SearchResult] = []
    var playlists: [SearchResult] = []
    var videos: [SearchResult] = []
    
    var isEmpty: Bool {
        songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty && videos.isEmpty
    }
    
    var totalCount: Int {
        songs.count + albums.count + artists.count + playlists.count + videos.count
    }
    
    mutating func clear() {
        songs.removeAll()
        albums.removeAll()
        artists.removeAll()
        playlists.removeAll()
        videos.removeAll()
    }
    
    func results(for type: SearchResultType) -> [SearchResult] {
        switch type {
        case .song: return songs
        case .album: return albums
        case .artist: return artists
        case .playlist: return playlists
        case .video: return videos
        }
    }
    
    mutating func setResults(_ results: [SearchResult], for type: SearchResultType) {
        switch type {
        case .song: songs = results
        case .album: albums = results
        case .artist: artists = results
        case .playlist: playlists = results
        case .video: videos = results
        }
    }
}

// MARK: - Track Model (for playback)

struct Track: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let thumbnailURL: String?
    let duration: TimeInterval
    let videoId: String
    let explicit: Bool
    let year: String?
    
    init(id: String = UUID().uuidString,
         title: String,
         artist: String,
         album: String? = nil,
         thumbnailURL: String? = nil,
         duration: TimeInterval,
         videoId: String,
         explicit: Bool = false,
         year: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.videoId = videoId
        self.explicit = explicit
        self.year = year
    }
    
    // Convert SearchResult to Track
    init(from searchResult: SearchResult) {
        self.id = searchResult.id
        self.title = searchResult.title
        self.artist = searchResult.artist ?? "Unknown Artist"
        self.album = nil
        self.thumbnailURL = searchResult.thumbnailURL
        self.duration = searchResult.duration ?? 0
        self.videoId = searchResult.videoId ?? ""
        self.explicit = searchResult.explicit
        self.year = searchResult.year
    }
}

// MARK: - Playback State

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
    case buffering
    case error(String)
    
    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped), (.playing, .playing), (.paused, .paused), (.buffering, .buffering):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
    
    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }
    
    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
    
    var isError: Bool {
        if case .error(_) = self { return true }
        return false
    }
}

// MARK: - Repeat Mode

enum RepeatMode: String, CaseIterable, Codable {
    case none = "none"
    case single = "single"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .none: return "Off"
        case .single: return "Single"
        case .all: return "All"
        }
    }
    
    var systemImage: String {
        switch self {
        case .none: return "repeat"
        case .single: return "repeat.1"
        case .all: return "repeat"
        }
    }
}

// MARK: - Stream Info

struct StreamInfo: Codable {
    let url: String
    let title: String
    let duration: TimeInterval
    let quality: String?
    
    init(url: String, title: String, duration: TimeInterval, quality: String? = nil) {
        self.url = url
        self.title = title
        self.duration = duration
        self.quality = quality
    }
}

// MARK: - Favorite Song Model

struct FavoriteSong: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String?
    let thumbnailURL: String?
    let duration: TimeInterval?
    let videoId: String
    let addedDate: Date
    
    init(from searchResult: SearchResult) {
        self.id = searchResult.id
        self.title = searchResult.title
        self.artist = searchResult.artist
        self.thumbnailURL = searchResult.thumbnailURL
        self.duration = searchResult.duration
        self.videoId = searchResult.videoId ?? ""
        self.addedDate = Date()
    }
}

// MARK: - Service Request/Response Models

struct SearchRequest: Codable {
    let query: String
    let limit: Int
    
    init(query: String, limit: Int = 20) {
        self.query = query
        self.limit = limit
    }
}

struct StreamRequest: Codable {
    let videoId: String
    
    init(videoId: String) {
        self.videoId = videoId
    }
}

struct ServiceResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    
    init(success: Bool, data: T? = nil, error: String? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
}

// MARK: - Playback Persistence

struct PlaybackData: Codable {
    let track: Track?
    let currentTime: TimeInterval
    let duration: TimeInterval
    let queue: [Track]
    let currentIndex: Int
    let shuffleEnabled: Bool
    let repeatMode: RepeatMode
    let wasPlaying: Bool
    
    init(track: Track?, 
         currentTime: TimeInterval, 
         duration: TimeInterval,
         queue: [Track],
         currentIndex: Int,
         shuffleEnabled: Bool,
         repeatMode: RepeatMode,
         wasPlaying: Bool) {
        self.track = track
        self.currentTime = currentTime
        self.duration = duration
        self.queue = queue
        self.currentIndex = currentIndex
        self.shuffleEnabled = shuffleEnabled
        self.repeatMode = repeatMode
        self.wasPlaying = wasPlaying
    }
}

// MARK: - Helper Extensions

extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension String {
    var isValidVideoId: Bool {
        return self.count == 11 && self.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil
    }
}