//
//  Playlist.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation

struct Playlist: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String?
    let thumbnailURL: String?
    let createdDate: Date
    var songs: [FavoriteSong]
    
    init(id: String = UUID().uuidString,
         name: String,
         description: String? = nil,
         thumbnailURL: String? = nil,
         createdDate: Date = Date(),
         songs: [FavoriteSong] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.createdDate = createdDate
        self.songs = songs
    }
    
    // Computed property for song count
    var songCount: Int {
        return songs.count
    }
    
    // Computed property for total duration
    var totalDuration: TimeInterval {
        return songs.reduce(0) { $0 + ($1.duration ?? 0) }
    }
    
    // Add a song to the playlist
    mutating func addSong(_ song: FavoriteSong) {
        // Check if song already exists in playlist
        if !songs.contains(where: { $0.videoId == song.videoId }) {
            songs.append(song)
        }
    }
    
    // Remove a song from the playlist
    mutating func removeSong(_ song: FavoriteSong) {
        songs.removeAll { $0.videoId == song.videoId }
    }
    
    // Remove a song by videoId
    mutating func removeSong(by videoId: String) {
        songs.removeAll { $0.videoId == videoId }
    }
    
    // Move a song within the playlist
    mutating func moveSong(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < songs.count && destinationIndex < songs.count else { return }
        guard sourceIndex != destinationIndex else { return }
        
        let movedSong = songs.remove(at: sourceIndex)
        songs.insert(movedSong, at: destinationIndex)
    }
    
    // Equatable conformance
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description &&
               lhs.thumbnailURL == rhs.thumbnailURL &&
               lhs.createdDate == rhs.createdDate &&
               lhs.songs.count == rhs.songs.count &&
               lhs.songs.elementsEqual(rhs.songs) { $0 == $1 }
    }
}