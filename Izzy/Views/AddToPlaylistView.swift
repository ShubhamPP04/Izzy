//
//  AddToPlaylistView.swift
//  Izzy
//
//  Created by Shubham Kumar on 02/09/25.
//

import SwiftUI

struct AddToPlaylistView: View {
    let song: SearchResult
    @ObservedObject var playlistManager: PlaylistManager
    @ObservedObject var searchState: SearchState
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add to Playlist")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Playlists list
            if playlistManager.playlists.isEmpty {
                HStack {
                    Text("No playlists available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(playlistManager.playlists) { playlist in
                            Button(action: {
                                // Convert SearchResult to FavoriteSong
                                let favoriteSong = FavoriteSong(from: song)
                                
                                // Add song to playlist
                                playlistManager.addSongToPlaylist(favoriteSong, playlistId: playlist.id)
                                
                                // Close the view
                                isPresented = false
                                
                                print("🎵 Added '\(song.title)' to playlist '\(playlist.name)'")
                            }) {
                                HStack {
                                    // Playlist thumbnail - use first song's artwork if playlist doesn't have one
                                    let playlistCoverURL = playlist.thumbnailURL ?? playlist.songs.first?.thumbnailURL
                                    AsyncImage(url: URL(string: playlistCoverURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay(
                                                Image(systemName: "music.note")
                                                    .foregroundColor(.secondary)
                                            )
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    
                                    // Playlist info
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Text("\(playlist.songCount) songs")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(width: 250, height: 300)
    }
}