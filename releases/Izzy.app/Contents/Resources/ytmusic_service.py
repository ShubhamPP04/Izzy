#!/usr/bin/env python3
"""
🔋 BATTERY OPTIMIZED: YouTube Music Service for Izzy Music Player
Handles search, stream URL extraction, and YouTube Music API interactions.
"""

import sys
import json
import asyncio
import logging
import traceback  # Add traceback for better error reporting
from typing import Dict, List, Any, Optional
from ytmusicapi import YTMusic

# Import additional libraries
try:
    import requests
    import re
    import base64
    import html  # For HTML entity decoding
    HAS_REQUESTS = True
    HAS_HTML = True
except ImportError:
    HAS_REQUESTS = False
    HAS_HTML = False
    print("❌ Failed to import requests for JioSaavn support", file=sys.stderr)

# Import yt-dlp with error handling
try:
    from yt_dlp import YoutubeDL
    HAS_YTDLP = True
    print("✅ Successfully imported yt-dlp", file=sys.stderr)
except ImportError as e:
    print(f"❌ Failed to import yt-dlp: {e}", file=sys.stderr)
    YoutubeDL = None
    HAS_YTDLP = False

# Check if ytmusicapi is available
try:
    HAS_YTMUSICAPI = True
    print("✅ Successfully imported ytmusicapi", file=sys.stderr)
except ImportError as e:
    HAS_YTMUSICAPI = False
    print(f"❌ Failed to import ytmusicapi: {e}", file=sys.stderr)

import sys
import json
import asyncio
import logging
import traceback  # Add traceback for better error reporting
from typing import Dict, List, Any, Optional
from ytmusicapi import YTMusic

# Import yt-dlp with error handling
try:
    from yt_dlp import YoutubeDL
    HAS_YTDLP = True
    print("✅ Successfully imported yt-dlp", file=sys.stderr)
except ImportError as e:
    print(f"❌ Failed to import yt-dlp: {e}", file=sys.stderr)
    YoutubeDL = None
    HAS_YTDLP = False

# 🔋 BATTERY OPTIMIZATION: Configure logging to reduce I/O
logging.basicConfig(
    level=logging.WARNING,  # Only log warnings and errors
    format='%(levelname)s: %(message)s',
    handlers=[logging.StreamHandler(sys.stderr)]
)
logger = logging.getLogger(__name__)

def decode_html_entities(text: str) -> str:
    """Safely decode HTML entities"""
    try:
        if HAS_HTML:
            return html.unescape(text)
        else:
            # Fallback manual decoding for common entities
            text = text.replace('&amp;', '&')
            text = text.replace('&quot;', '"')
            text = text.replace('&apos;', "'")
            text = text.replace('&lt;', '<')
            text = text.replace('&gt;', '>')
            return text
    except Exception:
        return text

# MARK: - JioSaavn Service

class JioSaavnService:
    """
    JioSaavn music service integration using saavn.dev API
    """
    
    def __init__(self):
        self.base_url = "https://saavn.dev/api"
        
    def search_all(self, query: str, limit: int = 20) -> Dict[str, Any]:
        """
        Search across JioSaavn music library using saavn.dev API
        """
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available - JioSaavn search not supported'
                }
            
            results = {
                'songs': [],
                'albums': [],
                'artists': [],
                'playlists': [],
                'videos': []
            }
            
            # Search songs
            try:
                songs_response = requests.get(f"{self.base_url}/search/songs", params={
                    'query': query,
                    'page': 0,
                    'limit': limit
                }, timeout=10)
                if songs_response.status_code == 200:
                    songs_data = songs_response.json()
                    if songs_data.get('success') and songs_data.get('data'):
                        for song in songs_data['data'].get('results', [])[:limit]:
                            formatted_song = self._format_jiosaavn_song(song)
                            if formatted_song:
                                results['songs'].append(formatted_song)
            except Exception as e:
                print(f"Error searching songs: {e}", file=sys.stderr)
            
            # Search albums
            try:
                albums_response = requests.get(f"{self.base_url}/search/albums", params={
                    'query': query,
                    'page': 0,
                    'limit': limit
                }, timeout=10)
                if albums_response.status_code == 200:
                    albums_data = albums_response.json()
                    if albums_data.get('success') and albums_data.get('data'):
                        for album in albums_data['data'].get('results', [])[:limit]:
                            formatted_album = self._format_jiosaavn_album(album)
                            if formatted_album:
                                results['albums'].append(formatted_album)
            except Exception as e:
                print(f"Error searching albums: {e}", file=sys.stderr)
            
            # Search artists
            try:
                artists_response = requests.get(f"{self.base_url}/search/artists", params={
                    'query': query,
                    'page': 0,
                    'limit': limit
                }, timeout=10)
                if artists_response.status_code == 200:
                    artists_data = artists_response.json()
                    if artists_data.get('success') and artists_data.get('data'):
                        for artist in artists_data['data'].get('results', [])[:limit]:
                            formatted_artist = self._format_jiosaavn_artist(artist)
                            if formatted_artist:
                                results['artists'].append(formatted_artist)
            except Exception as e:
                print(f"Error searching artists: {e}", file=sys.stderr)
            
            # Search playlists
            try:
                playlists_response = requests.get(f"{self.base_url}/search/playlists", params={
                    'query': query,
                    'page': 0,
                    'limit': limit
                }, timeout=10)
                if playlists_response.status_code == 200:
                    playlists_data = playlists_response.json()
                    if playlists_data.get('success') and playlists_data.get('data'):
                        for playlist in playlists_data['data'].get('results', [])[:limit]:
                            formatted_playlist = self._format_jiosaavn_playlist(playlist)
                            if formatted_playlist:
                                results['playlists'].append(formatted_playlist)
            except Exception as e:
                print(f"Error searching playlists: {e}", file=sys.stderr)
            
            return {
                'success': True,
                'data': results
            }
            
        except Exception as e:
            logger.error(f"JioSaavn search failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def _format_jiosaavn_song(self, song: Dict) -> Optional[Dict]:
        """Format JioSaavn song result from saavn.dev API"""
        try:
            # Get the highest quality image
            image_url = ''
            if song.get('image') and isinstance(song['image'], list) and len(song['image']) > 0:
                # Get the highest quality image (last in array)
                image_url = song['image'][-1].get('url', '') if song['image'][-1] else ''
            
            # Format artists
            artists_list = []
            if song.get('artists') and song['artists'].get('primary'):
                for artist in song['artists']['primary']:
                    if artist.get('name'):
                        # Decode HTML entities in artist names
                        artist_name = decode_html_entities(artist['name'].strip())
                        artists_list.append(artist_name)
            
            # Decode HTML entities in title
            title = decode_html_entities(song.get('name', '').strip())
            
            return {
                'id': song.get('id', ''),
                'type': 'songs',
                'title': title,
                'artist': ', '.join(artists_list) if artists_list else song.get('album', {}).get('name', ''),
                'thumbnailURL': image_url,
                'duration': float(song.get('duration', 0)) if song.get('duration') else None,
                'explicit': song.get('explicitContent', False),
                'videoId': song.get('id', ''),  # Use JioSaavn ID as videoId
                'browseId': None,
                'year': str(song.get('year', '')) if song.get('year') else None,
                'playCount': str(song.get('playCount', '')) if song.get('playCount') else None
            }
        except Exception as e:
            logger.error(f"Error formatting JioSaavn song: {e}")
            return None
    
    def _format_jiosaavn_album(self, album: Dict) -> Optional[Dict]:
        """Format JioSaavn album result from saavn.dev API"""
        try:
            # Get the highest quality image
            image_url = ''
            if album.get('image') and isinstance(album['image'], list) and len(album['image']) > 0:
                image_url = album['image'][-1].get('url', '') if album['image'][-1] else ''
            
            # Format artists
            artists_list = []
            if album.get('artists') and album['artists'].get('primary'):
                for artist in album['artists']['primary']:
                    if artist.get('name'):
                        # Decode HTML entities in artist names
                        artist_name = decode_html_entities(artist['name'].strip())
                        artists_list.append(artist_name)
            
            # Decode HTML entities in album title
            title = decode_html_entities(album.get('name', '').strip())
            
            return {
                'id': album.get('id', ''),
                'type': 'albums',
                'title': title,
                'artist': ', '.join(artists_list),
                'thumbnailURL': image_url,
                'duration': None,
                'explicit': album.get('explicitContent', False),
                'videoId': None,
                'browseId': album.get('id', ''),
                'year': str(album.get('year', '')) if album.get('year') else None,
                'playCount': str(album.get('playCount', '')) if album.get('playCount') else None
            }
        except Exception as e:
            logger.error(f"Error formatting JioSaavn album: {e}")
            return None
    
    def _format_jiosaavn_artist(self, artist: Dict) -> Optional[Dict]:
        """Format JioSaavn artist result from saavn.dev API"""
        try:
            # Get the highest quality image
            image_url = ''
            if artist.get('image') and isinstance(artist['image'], list) and len(artist['image']) > 0:
                image_url = artist['image'][-1].get('url', '') if artist['image'][-1] else ''
            
            # Decode HTML entities in artist name
            name = decode_html_entities(artist.get('name', '').strip())
            
            return {
                'id': artist.get('id', ''),
                'type': 'artists',
                'title': name,
                'artist': name,
                'thumbnailURL': image_url,
                'duration': None,
                'explicit': False,
                'videoId': None,
                'browseId': artist.get('id', ''),
                'year': None,
                'playCount': None
            }
        except Exception as e:
            logger.error(f"Error formatting JioSaavn artist: {e}")
            return None
    
    def _format_jiosaavn_playlist(self, playlist: Dict) -> Optional[Dict]:
        """Format JioSaavn playlist result from saavn.dev API"""
        try:
            # Get the highest quality image
            image_url = ''
            if playlist.get('image') and isinstance(playlist['image'], list) and len(playlist['image']) > 0:
                image_url = playlist['image'][-1].get('url', '') if playlist['image'][-1] else ''
            
            # Decode HTML entities in playlist name
            name = decode_html_entities(playlist.get('name', '').strip())
            
            return {
                'id': playlist.get('id', ''),
                'type': 'playlists',
                'title': name,
                'artist': 'JioSaavn Playlist',
                'thumbnailURL': image_url,
                'duration': None,
                'explicit': playlist.get('explicitContent', False),
                'videoId': None,
                'browseId': playlist.get('id', ''),
                'year': None,
                'playCount': str(playlist.get('songCount', '')) if playlist.get('songCount') else None
            }
        except Exception as e:
            logger.error(f"Error formatting JioSaavn playlist: {e}")
            return None
    
    def get_stream_info(self, video_id: str) -> Dict[str, Any]:
        """Get JioSaavn stream info using saavn.dev API"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available - JioSaavn streaming not supported'
                }
            
            print(f"🎵 Getting stream info for JioSaavn song ID: {video_id}", file=sys.stderr)
            
            # Get song details using the correct endpoint format
            response = requests.get(f"{self.base_url}/songs", params={
                'ids': video_id  # Use 'ids' instead of 'id'
            }, timeout=10)
            
            print(f"🎵 JioSaavn API response status: {response.status_code}", file=sys.stderr)
            
            if response.status_code != 200:
                # Try alternative endpoint format
                try:
                    response = requests.get(f"{self.base_url}/songs/{video_id}", timeout=10)
                    print(f"🎵 Alternative endpoint response: {response.status_code}", file=sys.stderr)
                except Exception as e:
                    print(f"🎵 Alternative endpoint failed: {e}", file=sys.stderr)
                
                if response.status_code != 200:
                    return {
                        'success': False,
                        'error': f'Failed to fetch song details: HTTP {response.status_code}'
                    }
            
            data = response.json()
            print(f"🎵 JioSaavn API response data keys: {list(data.keys()) if isinstance(data, dict) else f'List with {len(data)} items' if isinstance(data, list) else type(data)}", file=sys.stderr)
            
            if not data.get('success') or not data.get('data'):
                return {
                    'success': False,
                    'error': 'Song not found or no data available'
                }
            
            songs = data['data'] if isinstance(data['data'], list) else [data['data']]
            if not songs:
                return {
                    'success': False,
                    'error': 'No song data found'
                }
            
            song_data = songs[0]
            print(f"🎵 Song data keys: {list(song_data.keys()) if isinstance(song_data, dict) else f'Type: {type(song_data)}'}", file=sys.stderr)
            
            # Get stream URLs - JioSaavn provides multiple quality options
            download_url = ''
            quality = 'unknown'
            
            # Try to get the highest quality download URL
            if song_data.get('downloadUrl'):
                download_urls = song_data['downloadUrl']
                
                # Handle both dictionary and list formats  
                if isinstance(download_urls, dict):
                    print(f"🎵 Available download qualities (dict): {list(download_urls.keys())}", file=sys.stderr)
                    # Prefer 320kbps, then 160kbps, then 96kbps, then 48kbps
                    for qual in ['320kbps', '160kbps', '96kbps', '48kbps']:
                        if download_urls.get(qual):
                            download_url = download_urls[qual]
                            quality = qual
                            print(f"🎵 Selected quality: {quality}", file=sys.stderr)
                            break
                elif isinstance(download_urls, list) and len(download_urls) > 0:
                    # If it's a list of objects with quality and url properties (new API format)
                    print(f"🎵 Download URLs list format, {len(download_urls)} options available", file=sys.stderr)
                    # Look for the highest quality in the list
                    best_url = None
                    best_quality = 'unknown'
                    
                    # Sort by quality preference
                    quality_priority = {'320kbps': 5, '160kbps': 4, '96kbps': 3, '48kbps': 2, '12kbps': 1}
                    
                    for url_info in download_urls:
                        if isinstance(url_info, dict):
                            # Check for quality and url properties in the DownloadLink format
                            url = url_info.get('url')
                            quality_str = url_info.get('quality', 'unknown')
                            
                            if url:
                                # Prioritize higher quality
                                current_priority = quality_priority.get(quality_str, 0)
                                best_priority = quality_priority.get(best_quality, 0)
                                
                                if best_url is None or current_priority > best_priority:
                                    best_url = url
                                    best_quality = quality_str
                                    print(f"🎵 Found better quality: {quality_str}", file=sys.stderr)
                        elif isinstance(url_info, str):
                            # Fallback for direct URL strings
                            if best_url is None:
                                best_url = url_info
                                best_quality = 'unknown'
                    
                    if best_url:
                        download_url = best_url
                        quality = best_quality
                        print(f"🎵 Selected URL from list: {quality}", file=sys.stderr)
                else:
                    print(f"🎵 Unexpected downloadUrl format: {type(download_urls)}", file=sys.stderr)
            else:
                # Check for alternative field names
                for field in ['media_url', 'stream_url', 'url', 'link']:
                    if song_data.get(field):
                        download_url = song_data[field]
                        quality = 'default'
                        print(f"🎵 Using alternative field '{field}' for stream URL", file=sys.stderr)
                        break
            
            if not download_url:
                return {
                    'success': False,
                    'error': 'No stream URL available for this song'
                }
            
            return {
                'success': True,
                'data': {
                    'url': download_url,
                    'title': song_data.get('name', ''),
                    'duration': int(song_data.get('duration', 0)),
                    'quality': quality
                }
            }
            
        except Exception as e:
            logger.error(f"JioSaavn stream extraction failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_album_tracks(self, browse_id: str) -> Dict[str, Any]:
        """Get tracks from a JioSaavn album using saavn.dev API"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            response = requests.get(f"{self.base_url}/albums", params={
                'id': browse_id
            }, timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch album: HTTP {response.status_code}'
                }
            
            data = response.json()
            if not data.get('success') or not data.get('data'):
                return {
                    'success': False,
                    'error': 'Album not found'
                }
            
            album_data = data['data']
            tracks = []
            
            if album_data.get('songs'):
                for song in album_data['songs']:
                    formatted_song = self._format_jiosaavn_song(song)
                    if formatted_song:
                        tracks.append(formatted_song)
            
            return {
                'success': True,
                'data': tracks
            }
            
        except Exception as e:
            logger.error(f"JioSaavn album tracks failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_playlist_tracks(self, playlist_id: str) -> Dict[str, Any]:
        """Get tracks from a JioSaavn playlist using saavn.dev API"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            response = requests.get(f"{self.base_url}/playlists", params={
                'id': playlist_id
            }, timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch playlist: HTTP {response.status_code}'
                }
            
            data = response.json()
            if not data.get('success') or not data.get('data'):
                return {
                    'success': False,
                    'error': 'Playlist not found'
                }
            
            playlist_data = data['data']
            tracks = []
            
            if playlist_data.get('songs'):
                for song in playlist_data['songs']:
                    formatted_song = self._format_jiosaavn_song(song)
                    if formatted_song:
                        tracks.append(formatted_song)
            
            return {
                'success': True,
                'data': tracks
            }
            
        except Exception as e:
            logger.error(f"JioSaavn playlist tracks failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_artist_songs(self, browse_id: str) -> Dict[str, Any]:
        """Get songs from a JioSaavn artist using saavn.dev API"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            response = requests.get(f"{self.base_url}/artists", params={
                'id': browse_id
            }, timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch artist: HTTP {response.status_code}'
                }
            
            data = response.json()
            if not data.get('success') or not data.get('data'):
                return {
                    'success': False,
                    'error': 'Artist not found'
                }
            
            artist_data = data['data']
            tracks = []
            
            # Get songs from topSongs
            if artist_data.get('topSongs'):
                for song in artist_data['topSongs']:
                    formatted_song = self._format_jiosaavn_song(song)
                    if formatted_song:
                        tracks.append(formatted_song)
            
            return {
                'success': True,
                'data': tracks
            }
            
        except Exception as e:
            logger.error(f"JioSaavn artist songs failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_watch_playlist(self, video_id: str, playlist_id: str = None) -> Dict[str, Any]:
        """Get watch playlist for JioSaavn using song suggestions"""
        try:
            return self.get_song_suggestions(video_id)
        except Exception as e:
            logger.error(f"JioSaavn watch playlist failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_song_suggestions(self, video_id: str) -> Dict[str, Any]:
        """Get song suggestions for JioSaavn using saavn.dev API"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            response = requests.get(f"{self.base_url}/songs/{video_id}/suggestions", timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch suggestions: HTTP {response.status_code}'
                }
            
            data = response.json()
            if not data.get('success') or not data.get('data'):
                return {
                    'success': False,
                    'error': 'No suggestions found'
                }
            
            tracks = []
            for song in data['data']:
                formatted_song = self._format_jiosaavn_song(song)
                if formatted_song:
                    tracks.append(formatted_song)
            
            return {
                'success': True,
                'data': tracks
            }
            
        except Exception as e:
            logger.error(f"JioSaavn song suggestions failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_lyrics(self, video_id: str) -> Dict[str, Any]:
        """Get lyrics for JioSaavn song using saavn.dev API"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            response = requests.get(f"{self.base_url}/songs", params={
                'id': video_id
            }, timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch song details: HTTP {response.status_code}'
                }
            
            data = response.json()
            if not data.get('success') or not data.get('data'):
                return {
                    'success': False,
                    'error': 'Song not found'
                }
            
            songs = data['data'] if isinstance(data['data'], list) else [data['data']]
            if not songs:
                return {
                    'success': False,
                    'error': 'No song data found'
                }
            
            song_data = songs[0]
            
            # Check if lyrics are available
            if song_data.get('lyrics'):
                return {
                    'success': True,
                    'data': {
                        'lyrics': song_data['lyrics'],
                        'source': 'JioSaavn'
                    }
                }
            else:
                return {
                    'success': False,
                    'error': 'No lyrics found for this song'
                }
            
        except Exception as e:
            logger.error(f"JioSaavn lyrics failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

# MARK: - YouTube Music Service

# 🔋 BATTERY OPTIMIZATION: Check for optional dependencies
HAS_YTMUSICAPI = True

try:
    import aiohttp
except ImportError:
    # aiohttp is optional for basic functionality
    pass

class YTMusicService:
    def __init__(self):
        try:
            if HAS_YTMUSICAPI:
                # Initialize YTMusic without authentication for basic search
                self.yt = YTMusic()
            else:
                self.yt = None
            
            # 🔋 BATTERY OPTIMIZATION: Configure yt-dlp for minimal resource usage
            if HAS_YTDLP:
                self.ydl_opts = {
                    'format': 'bestaudio/best',
                    'quiet': True,
                    'no_warnings': True,
                    'extractaudio': True,
                    'audioformat': 'best',
                    'noplaylist': True,
                    'no_check_certificate': True,
                    # 🔋 Reduce network usage and CPU overhead
                    'socket_timeout': 30,  # Faster timeout to avoid hanging
                    'retries': 1,  # Reduce retry attempts
                    'fragment_retries': 1,  # Reduce fragment retries
                    'skip_unavailable_fragments': True,  # Skip bad fragments quickly
                    'writeinfojson': False,  # Don't write metadata files
                    'writesubtitles': False,  # Don't download subtitles
                    'writeautomaticsub': False,  # Don't download auto-generated subs
                }
            
        except Exception as e:
            logger.error(f"Failed to initialize YTMusicService: {e}")
            raise
    
    def search_all(self, query: str, limit: int = 20) -> Dict[str, Any]:
        """
        Search across all categories: songs, albums, artists, playlists, videos
        """
        try:
            if HAS_YTMUSICAPI and self.yt:
                print(f"Using ytmusicapi for search: {query}", file=sys.stderr)
                results = self._search_with_ytmusicapi(query, limit)
                return {
                    'success': True,
                    'data': results  # Return the MusicSearchResults structure directly
                }
            else:
                print(f"Using fallback search for: {query}", file=sys.stderr)
                results = self._search_fallback(query, limit)
                return {
                    'success': True,
                    'data': results  # Return the MusicSearchResults structure directly
                }
            
        except Exception as e:
            logger.error(f"Search failed: {e}")
            print(f"Search error: {e}", file=sys.stderr)
            return {
                'success': False,
                'error': str(e)
            }
    
    def _search_with_ytmusicapi(self, query: str, limit: int) -> Dict[str, Any]:
        """
        Search using ytmusicapi (preferred method)
        Enhanced with better error handling and search optimization
        """
        results = {}
        
        # Search each category with proper ytmusicapi filters
        search_filters = {
            'songs': 'songs',
            'albums': 'albums', 
            'artists': 'artists',
            'playlists': 'playlists',
            'videos': 'videos'
        }
        
        for category, filter_name in search_filters.items():
            try:
                print(f"Searching {category} for: '{query}' with filter '{filter_name}'", file=sys.stderr)
                
                # Use ytmusicapi search with proper filter
                search_results = self.yt.search(query, filter=filter_name, limit=limit)
                print(f"Got {len(search_results)} {category} results", file=sys.stderr)
                
                # Format results
                formatted_results = self._format_search_results(search_results, category)
                results[category] = formatted_results
                print(f"Formatted {len(formatted_results)} {category} results", file=sys.stderr)
                
            except Exception as e:
                logger.error(f"Error searching {category}: {e}")
                print(f"Error searching {category}: {e}", file=sys.stderr)
                results[category] = []
        
        return results
    
    def _search_fallback(self, query: str, limit: int) -> Dict[str, Any]:
        """
        Fallback search method using basic YouTube search
        """
        try:
            # Create mock results for demonstration
            # In a real implementation, you could use YouTube Data API or web scraping
            # Use some real YouTube video IDs for testing (these are public domain/creative commons)
            test_video_ids = [
                'dQw4w9WgXcQ',  # Rick Astley - Never Gonna Give You Up
                'kJQP7kiw5Fk',  # Luis Fonsi - Despacito
                'JGwWNGJdvx8',  # Ed Sheeran - Shape of You
                'fJ9rUzIMcZQ',  # Queen - Bohemian Rhapsody
                'hTWKbfoikeg'   # Nirvana - Smells Like Teen Spirit
            ]
            
            mock_results = {
                'songs': [
                    {
                        'id': f'mock_song_{i}',
                        'type': 'songs',
                        'title': f'Test Song {i + 1} for "{query}"',
                        'artist': 'Test Artist',
                        'thumbnailURL': 'https://via.placeholder.com/120x120?text=Music',
                        'duration': 180.0,
                        'explicit': False,
                        'videoId': test_video_ids[i % len(test_video_ids)],
                        'browseId': None,
                        'year': None,
                        'playCount': None
                    } for i in range(min(limit, 5))
                ],
                'albums': [],
                'artists': [],
                'playlists': [],
                'videos': []
            }
            
            return mock_results
            
        except Exception as e:
            logger.error(f"Fallback search failed: {e}")
            raise Exception(f"Fallback search failed: {str(e)}")
    
    def _format_search_results(self, raw_results: List[Dict], category: str) -> List[Dict]:
        """
        Format raw search results into consistent structure
        """
        formatted_results = []
        
        for item in raw_results:
            try:
                # Skip invalid items
                if not item or not isinstance(item, dict):
                    logger.warning(f"Skipping invalid item in {category}: {type(item)}")
                    continue
                    
                formatted_item = self._format_single_result(item, category)
                if formatted_item:
                    formatted_results.append(formatted_item)
            except Exception as e:
                logger.error(f"Error formatting result in {category}: {e}")
                continue
        
        return formatted_results
    
    def _format_single_result(self, item: Dict, category: str) -> Optional[Dict]:
        """
        Format a single search result item
        """
        try:
            # Skip if item is not a dictionary (sometimes ytmusicapi returns strings)
            if not isinstance(item, dict):
                logger.warning(f"Skipping non-dict item: {type(item)} - {item}")
                return None
            
            # Helper function to safely get values from potentially mixed data types
            def safe_get(obj, key, default=''):
                if isinstance(obj, dict):
                    return obj.get(key, default)
                elif isinstance(obj, str):
                    return obj if key == 'name' or key == 'title' else default
                else:
                    return default
                    
            # Helper function to safely get numeric values for calculations
            def safe_get_int(obj, key, default=0):
                try:
                    val = safe_get(obj, key, default)
                    return int(val) if val and str(val).isdigit() else default
                except (ValueError, TypeError):
                    return default
                    
            # Helper function to ensure we have a list for iteration
            def ensure_list(obj):
                if isinstance(obj, list):
                    return obj
                elif obj is None:
                    return []
                elif isinstance(obj, str):
                    return [obj] if obj else []
                else:
                    return [obj]
            
            # Skip items without essential data
            title = safe_get(item, 'title', '').strip()
            if not title and category != 'artists':
                logger.warning(f"Skipping item without title in {category}")
                return None
            
            # Common fields - match Swift SearchResult struct exactly
            result = {
                'id': safe_get(item, 'videoId') or safe_get(item, 'browseId') or safe_get(item, 'playlistId', ''),
                'type': category,
                'title': title,
                'artist': None,  # Will be set below based on category
                'thumbnailURL': None,  # Will be set below
                'duration': None,  # Will be set below
                'explicit': safe_get(item, 'isExplicit', False),
                'videoId': safe_get(item, 'videoId'),
                'browseId': safe_get(item, 'browseId'),
                'year': None,  # Will be set below
                'playCount': None  # Will be set below
            }
            
            # Handle thumbnails
            thumbnails_raw = safe_get(item, 'thumbnails', [])
            thumbnails = ensure_list(thumbnails_raw)
            if thumbnails:
                # Filter to only dictionary thumbnails and find highest quality
                valid_thumbnails = [t for t in thumbnails if isinstance(t, dict)]
                if valid_thumbnails:
                    thumbnail = max(valid_thumbnails, key=lambda x: safe_get_int(x, 'width', 0) * safe_get_int(x, 'height', 0))
                    result['thumbnailURL'] = safe_get(thumbnail, 'url')
            
            # Category-specific formatting
            if category == 'songs':
                artists_raw = safe_get(item, 'artists', [])
                artists = ensure_list(artists_raw)
                if artists:
                    artist_names = []
                    for artist in artists:
                        if isinstance(artist, dict):
                            name = safe_get(artist, 'name', '')
                        elif isinstance(artist, str):
                            name = artist
                        else:
                            continue
                        if name:
                            artist_names.append(name)
                    
                    if artist_names:
                        result['artist'] = ', '.join(artist_names)
                
                # Duration
                duration_text = safe_get(item, 'duration')
                if duration_text:
                    result['duration'] = self._parse_duration(duration_text)
                
                # Year
                result['year'] = safe_get(item, 'year')
                
            elif category == 'albums':
                artists_raw = safe_get(item, 'artists', [])
                artists = ensure_list(artists_raw)
                if artists:
                    artist_names = []
                    for artist in artists:
                        if isinstance(artist, dict):
                            name = safe_get(artist, 'name', '')
                        elif isinstance(artist, str):
                            name = artist
                        else:
                            continue
                        if name:
                            artist_names.append(name)
                    
                    if artist_names:
                        result['artist'] = ', '.join(artist_names)
                
                result['year'] = safe_get(item, 'year')
                
            elif category == 'artists':
                # For artists, use the artist field, name field, or title field
                artist_name = safe_get(item, 'artist') or safe_get(item, 'name') or safe_get(item, 'title', '').strip()
                if not artist_name:
                    logger.warning(f"Skipping artist without name: {item}")
                    return None
                result['title'] = artist_name
                result['artist'] = artist_name
                subscribers = safe_get(item, 'subscribers')
                if subscribers:
                    result['playCount'] = subscribers
                
            elif category == 'playlists':
                author = safe_get(item, 'author')
                if author:
                    if isinstance(author, dict):
                        result['artist'] = safe_get(author, 'name', '')
                    elif isinstance(author, str):
                        result['artist'] = author
                
            elif category == 'videos':
                artists_raw = safe_get(item, 'artists', [])
                artists = ensure_list(artists_raw)
                if artists:
                    artist_names = []
                    for artist in artists:
                        if isinstance(artist, dict):
                            name = safe_get(artist, 'name', '')
                        elif isinstance(artist, str):
                            name = artist
                        else:
                            continue
                        if name:
                            artist_names.append(name)
                    
                    if artist_names:
                        result['artist'] = ', '.join(artist_names)
                
                # Duration
                duration_text = safe_get(item, 'duration')
                if duration_text:
                    result['duration'] = self._parse_duration(duration_text)
                
                # Views
                views = safe_get(item, 'views')
                if views:
                    result['playCount'] = views
            
            return result
            
        except Exception as e:
            logger.error(f"Error formatting single result: {e}")
            logger.error(f"Item data: {json.dumps(item, indent=2) if isinstance(item, dict) else str(item)}")
            logger.error(f"Traceback: {traceback.format_exc()}")
            return None
    
    def _parse_duration(self, duration_text: str) -> Optional[float]:
        """
        Parse duration text like "3:45" into seconds
        """
        try:
            if not duration_text:
                return None
            
            parts = duration_text.split(':')
            if len(parts) == 2:
                minutes, seconds = int(parts[0]), int(parts[1])
                return minutes * 60 + seconds
            elif len(parts) == 3:
                hours, minutes, seconds = int(parts[0]), int(parts[1]), int(parts[2])
                return hours * 3600 + minutes * 60 + seconds
            
        except (ValueError, IndexError):
            pass
        
        return None
    
    def get_stream_info(self, video_id: str) -> Dict[str, Any]:
        """
        Extract stream URL and metadata for a video ID using yt-dlp or fallback
        """
        try:
            if HAS_YTDLP:
                print(f"Using yt-dlp for stream extraction: {video_id}", file=sys.stderr)
                return self._get_stream_with_ytdlp(video_id)
            else:
                print(f"yt-dlp not available, using fallback for: {video_id}", file=sys.stderr)
                return self._get_stream_fallback(video_id)
                
        except Exception as e:
            logger.error(f"Stream extraction failed for {video_id}: {e}")
            return {
                'success': False,
                'error': f"Stream extraction failed: {str(e)}"
            }
    
    def _get_stream_with_ytdlp(self, video_id: str) -> Dict[str, Any]:
        """
        Extract stream using yt-dlp (preferred method)
        Enhanced with better audio quality selection and error handling
        """
        # Try both YouTube Music and regular YouTube URLs
        urls_to_try = [
            f"https://music.youtube.com/watch?v={video_id}",
            f"https://www.youtube.com/watch?v={video_id}"
        ]
        
        # Enhanced yt-dlp options for better audio quality
        enhanced_opts = {
            'format': 'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio/best',
            'quiet': True,
            'no_warnings': True,
            'extractaudio': True,
            'audioformat': 'best',
            'noplaylist': True,
            'no_check_certificate': True,
            'prefer_free_formats': False,  # Prefer higher quality formats
            'youtube_include_dash_manifest': False,  # Avoid DASH for compatibility
        }
        
        last_error = None
        
        for url in urls_to_try:
            try:
                print(f"Trying to extract stream from: {url}", file=sys.stderr)
                
                if not HAS_YTDLP or YoutubeDL is None:
                    raise Exception("yt-dlp is not available")
                
                with YoutubeDL(enhanced_opts) as ydl:
                    info = ydl.extract_info(url, download=False)
                    
                    # Extract the best audio stream URL
                    stream_url = info.get('url')
                    if not stream_url:
                        # Try formats if direct URL not available
                        formats = info.get('formats', [])
                        audio_formats = [f for f in formats if f.get('acodec') != 'none']
                        if audio_formats:
                            # Get the best quality audio format (prefer m4a, then webm, then others)
                            def format_priority(fmt):
                                ext = fmt.get('ext', '')
                                abr = fmt.get('abr', 0)
                                if ext == 'm4a':
                                    return (3, abr)
                                elif ext == 'webm':
                                    return (2, abr)
                                else:
                                    return (1, abr)
                            
                            best_format = max(audio_formats, key=format_priority)
                            stream_url = best_format.get('url')
                    
                    if not stream_url:
                        raise Exception("No valid stream URL found")
                    
                    # Convert quality to string to match Swift expectations
                    quality = info.get('abr')
                    if quality is None:
                        # Try to get quality from format
                        formats = info.get('formats', [])
                        if formats:
                            quality = formats[0].get('abr')
                    
                    quality_str = str(quality) if quality is not None else 'unknown'
                    
                    print(f"Successfully extracted stream: quality={quality_str}, duration={info.get('duration', 0)}", file=sys.stderr)
                    
                    return {
                        'success': True,
                        'data': {
                            'url': stream_url,
                            'title': info.get('title', ''),
                            'duration': info.get('duration', 0),
                            'quality': quality_str
                        }
                    }
                    
            except Exception as e:
                last_error = e
                print(f"Failed to extract from {url}: {e}", file=sys.stderr)
                continue
        
        # If we get here, all URLs failed
        raise Exception(f"Stream extraction failed for all URLs. Last error: {last_error}")
    
    def _get_stream_fallback(self, video_id: str) -> Dict[str, Any]:
        """
        Fallback stream extraction - returns error since we can't actually stream without yt-dlp
        """
        # Without yt-dlp, we can't extract real stream URLs
        # Return an error to inform the user that streaming requires yt-dlp
        
        # Check if this is one of our test video IDs
        test_titles = {
            'dQw4w9WgXcQ': 'Rick Astley - Never Gonna Give You Up',
            'kJQP7kiw5Fk': 'Luis Fonsi - Despacito', 
            'JGwWNGJdvx8': 'Ed Sheeran - Shape of You',
            'fJ9rUzIMcZQ': 'Queen - Bohemian Rhapsody',
            'hTWKbfoikeg': 'Nirvana - Smells Like Teen Spirit'
        }
        
        title = test_titles.get(video_id, f'Test Video {video_id}')
        
        return {
            'success': False,
            'error': f'Cannot stream "{title}" - yt-dlp is required for audio playback. Install with: pip install yt-dlp'
        }
    
    def get_album_tracks(self, browse_id: str) -> Dict[str, Any]:
        """
        Get tracks from an album
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - album tracks not supported'
                }
                
            album_info = self.yt.get_album(browse_id)
            tracks = album_info.get('tracks', [])
            
            formatted_tracks = []
            for track in tracks:
                formatted_track = self._format_single_result(track, 'songs')
                if formatted_track:
                    formatted_tracks.append(formatted_track)
            
            return {
                'success': True,
                'data': formatted_tracks
            }
            
        except Exception as e:
            logger.error(f"Failed to get album tracks: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_playlist_tracks(self, playlist_id: str) -> Dict[str, Any]:
        """
        Get tracks from a playlist
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - playlist tracks not supported'
                }
                
            playlist_info = self.yt.get_playlist(playlist_id)
            tracks = playlist_info.get('tracks', [])
            
            formatted_tracks = []
            for track in tracks:
                formatted_track = self._format_single_result(track, 'songs')
                if formatted_track:
                    formatted_tracks.append(formatted_track)
            
            return {
                'success': True,
                'data': formatted_tracks
            }
            
        except Exception as e:
            logger.error(f"Failed to get playlist tracks: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_artist_songs(self, browse_id: str) -> Dict[str, Any]:
        """
        Get songs from an artist
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - artist songs not supported'
                }
                
            artist_info = self.yt.get_artist(browse_id)
            songs = artist_info.get('songs', {}).get('results', [])
            
            formatted_songs = []
            for song in songs:
                formatted_song = self._format_single_result(song, 'songs')
                if formatted_song:
                    formatted_songs.append(formatted_song)
            
            return {
                'success': True,
                'data': formatted_songs
            }
            
        except Exception as e:
            logger.error(f"Failed to get artist songs: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_watch_playlist(self, video_id: str, playlist_id: str = None) -> Dict[str, Any]:
        """
        Get watch playlist (radio/shuffle) for a song - this creates a continuous playlist
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - watch playlist not supported'
                }
            
            # Get watch playlist (radio) for the video
            watch_playlist = self.yt.get_watch_playlist(videoId=video_id, playlistId=playlist_id)
            tracks = watch_playlist.get('tracks', [])
            
            formatted_tracks = []
            for track in tracks:
                formatted_track = self._format_single_result(track, 'songs')
                if formatted_track:
                    formatted_tracks.append(formatted_track)
            
            print(f"Generated watch playlist with {len(formatted_tracks)} tracks", file=sys.stderr)
            
            return {
                'success': True,
                'data': formatted_tracks
            }
            
        except Exception as e:
            logger.error(f"Failed to get watch playlist: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_song_suggestions(self, video_id: str) -> Dict[str, Any]:
        """
        Get song suggestions/related tracks for a video
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - song suggestions not supported'
                }
            
            # Get related songs
            related = self.yt.get_song_related(video_id)
            
            formatted_tracks = []
            for track in related:
                formatted_track = self._format_single_result(track, 'songs')
                if formatted_track:
                    formatted_tracks.append(formatted_track)
            
            return {
                'success': True,
                'data': formatted_tracks
            }
            
        except Exception as e:
            logger.error(f"Failed to get song suggestions: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_lyrics(self, video_id: str) -> Dict[str, Any]:
        """
        Get lyrics for a song
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - lyrics not supported'
                }
            
            # Get lyrics
            lyrics_data = self.yt.get_lyrics(video_id)
            
            if lyrics_data:
                return {
                    'success': True,
                    'data': {
                        'lyrics': lyrics_data.get('lyrics', ''),
                        'source': lyrics_data.get('source', 'YouTube Music')
                    }
                }
            else:
                return {
                    'success': False,
                    'error': 'No lyrics found for this song'
                }
            
        except Exception as e:
            logger.error(f"Failed to get lyrics: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_mood_categories(self) -> Dict[str, Any]:
        """
        Get mood & genre categories from YouTube Music explore section
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - mood categories not supported'
                }
            
            # Get mood categories
            mood_data = self.yt.get_mood_categories()
            
            print(f"Retrieved mood categories with {len(mood_data)} sections", file=sys.stderr)
            
            return {
                'success': True,
                'data': mood_data
            }
            
        except Exception as e:
            logger.error(f"Failed to get mood categories: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_mood_playlists(self, params: str) -> Dict[str, Any]:
        """
        Get playlists for a specific mood/genre category
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - mood playlists not supported'
                }
            
            # Get playlists for the mood category
            playlists_data = self.yt.get_mood_playlists(params)
            
            print(f"Retrieved {len(playlists_data)} mood playlists", file=sys.stderr)
            
            return {
                'success': True,
                'data': playlists_data
            }
            
        except Exception as e:
            logger.error(f"Failed to get mood playlists: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_charts(self, country: str = 'ZZ') -> Dict[str, Any]:
        """
        Get charts data from YouTube Music (top songs, artists, etc.)
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - charts not supported'
                }
            
            # Get charts data
            charts_data = self.yt.get_charts(country)
            
            print(f"Retrieved charts for country {country}", file=sys.stderr)
            
            return {
                'success': True,
                'data': charts_data
            }
            
        except Exception as e:
            logger.error(f"Failed to get charts: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_home(self) -> Dict[str, Any]:
        """
        Get home feed from YouTube Music
        """
        try:
            if not HAS_YTMUSICAPI or not self.yt:
                return {
                    'success': False,
                    'error': 'ytmusicapi not available - home feed not supported'
                }
            
            # Get home feed
            home_data = self.yt.get_home(limit=20)
            
            print(f"Retrieved home feed with {len(home_data)} sections", file=sys.stderr)
            
            return {
                'success': True,
                'data': home_data
            }
            
        except Exception as e:
            logger.error(f"Failed to get home feed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

def handle_request(request_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle incoming requests from Swift
    """
    try:
        # Get the music source from the request (default to YouTube Music)
        music_source = request_data.get('musicSource', 'youtube_music')
        print(f"🎵 Python received musicSource: '{music_source}'", file=sys.stderr)
        
        if music_source == 'jiosaavn':
            print("🔥 Using JioSaavn service", file=sys.stderr)
            service = JioSaavnService()
        else:
            print("🔥 Using YouTube Music service", file=sys.stderr)
            service = YTMusicService()
            
        action = request_data.get('action')
        print(f"🎵 Action: {action}", file=sys.stderr)
        
        if action == 'search':
            query = request_data.get('query', '')
            limit = request_data.get('limit', 20)
            return service.search_all(query, limit)
            
        elif action == 'stream':
            video_id = request_data.get('videoId', '')
            return service.get_stream_info(video_id)
            
        elif action == 'album_tracks':
            browse_id = request_data.get('browseId', '')
            return service.get_album_tracks(browse_id)
            
        elif action == 'playlist_tracks':
            playlist_id = request_data.get('playlistId', '')
            return service.get_playlist_tracks(playlist_id)
            
        elif action == 'artist_songs':
            browse_id = request_data.get('browseId', '')
            return service.get_artist_songs(browse_id)
            
        elif action == 'watch_playlist':
            video_id = request_data.get('videoId', '')
            playlist_id = request_data.get('playlistId')  # Optional
            return service.get_watch_playlist(video_id, playlist_id)
            
        elif action == 'song_suggestions':
            video_id = request_data.get('videoId', '')
            return service.get_song_suggestions(video_id)
            
        elif action == 'lyrics':
            video_id = request_data.get('videoId', '')
            return service.get_lyrics(video_id)
            
        elif action == 'mood_categories':
            return service.get_mood_categories()
            
        elif action == 'mood_playlists':
            params = request_data.get('params', '')
            return service.get_mood_playlists(params)
            
        elif action == 'charts':
            country = request_data.get('country', 'ZZ')
            return service.get_charts(country)
            
        elif action == 'home':
            return service.get_home()
            
        else:
            return {
                'success': False,
                'error': f'Unknown action: {action}'
            }
            
    except Exception as e:
        logger.error(f"Request handling failed: {e}")
        return {
            'success': False,
            'error': str(e)
        }

def main():
    """
    Main service loop - reads JSON requests from stdin, writes responses to stdout
    """
    # Send startup confirmation
    startup_response = {
        'success': True,
        'data': {'status': 'service_ready', 'has_ytmusicapi': HAS_YTMUSICAPI, 'has_ytdlp': HAS_YTDLP}
    }
    print(json.dumps(startup_response), flush=True)
    
    try:
        while True:
            try:
                # Read request from stdin
                line = sys.stdin.readline()
                if not line:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                # Log to stderr for debugging
                print(f"Received request: {line}", file=sys.stderr, flush=True)
                
                request_data = json.loads(line)
                response = handle_request(request_data)
                
                # Log response to stderr for debugging
                print(f"Sending response: {json.dumps(response)}", file=sys.stderr, flush=True)
                
                # Write response to stdout
                print(json.dumps(response), flush=True)
                
            except json.JSONDecodeError as e:
                error_response = {
                    'success': False,
                    'error': f'Invalid JSON: {str(e)}'
                }
                print(f"JSON decode error: {e}", file=sys.stderr, flush=True)
                print(json.dumps(error_response), flush=True)
                
            except Exception as e:
                error_response = {
                    'success': False,
                    'error': str(e)
                }
                print(f"Request error: {e}", file=sys.stderr, flush=True)
                print(json.dumps(error_response), flush=True)
                
    except KeyboardInterrupt:
        print("Service interrupted", file=sys.stderr, flush=True)
        pass
    except Exception as e:
        print(f"Main loop error: {e}", file=sys.stderr, flush=True)

if __name__ == '__main__':
    main()