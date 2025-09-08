//
//  PlaylistManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import Foundation
import Combine

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    @Published var playlists: [Playlist] = []
    
    private let playlistsKey = "IzzyPlaylists"
    
    private init() {
        loadPlaylists()
    }
    
    // MARK: - Playlist Management
    
    func createPlaylist(name: String, description: String? = nil, thumbnailURL: String? = nil) -> Playlist {
        let newPlaylist = Playlist(
            name: name,
            description: description,
            thumbnailURL: thumbnailURL
        )
        playlists.append(newPlaylist)
        savePlaylists()
        return newPlaylist
    }
    
    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }
    
    func updatePlaylist(_ playlist: Playlist) {
        if let index = playlists.firstIndex(where: { $0.id == playlist.id }) {
            playlists[index] = playlist
            savePlaylists()
        }
    }
    
    func addSongToPlaylist(_ song: FavoriteSong, playlistId: String) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var updatedPlaylist = playlists[index]
            updatedPlaylist.addSong(song)
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    func removeSongFromPlaylist(_ song: FavoriteSong, playlistId: String) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var updatedPlaylist = playlists[index]
            updatedPlaylist.removeSong(song)
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    func removeSongFromPlaylist(songVideoId: String, playlistId: String) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var updatedPlaylist = playlists[index]
            updatedPlaylist.removeSong(by: songVideoId)
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    // Add a method to move songs within a playlist
    func moveSongInPlaylist(playlistId: String, from sourceIndex: Int, to destinationIndex: Int) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var updatedPlaylist = playlists[index]
            updatedPlaylist.moveSong(from: sourceIndex, to: destinationIndex)
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    // Add a method to move multiple songs within a playlist
    func moveSongsInPlaylist(playlistId: String, from indices: IndexSet, to newOffset: Int) {
        if let index = playlists.firstIndex(where: { $0.id == playlistId }) {
            var updatedPlaylist = playlists[index]
            
            // Move the songs using the built-in move method
            updatedPlaylist.songs.move(fromOffsets: indices, toOffset: newOffset)
            
            playlists[index] = updatedPlaylist
            savePlaylists()
        }
    }
    
    // MARK: - Persistence
    
    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            UserDefaults.standard.set(data, forKey: playlistsKey)
        } catch {
            print("❌ Failed to save playlists: \(error)")
        }
    }
    
    private func loadPlaylists() {
        // Load playlists
        if let data = UserDefaults.standard.data(forKey: playlistsKey) {
            do {
                playlists = try JSONDecoder().decode([Playlist].self, from: data)
            } catch {
                print("❌ Failed to load playlists: \(error)")
                playlists = []
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func getPlaylist(by id: String) -> Playlist? {
        return playlists.first { $0.id == id }
    }
    
    func playlistExists(with name: String) -> Bool {
        return playlists.contains { $0.name.lowercased() == name.lowercased() }
    }
}