#!/usr/bin/env python3
"""
🔋 BATTERY OPTIMIZED: YouTube Music Service for Izzy Music Player
Handles search, stream URL extraction, and YouTube Music API interactions.
"""

import sys
import json
import asyncio
import logging
import time
import traceback  # Add traceback for better error reporting
from typing import Dict, List, Any, Optional
try:
    from ytmusicapi import YTMusic
    HAS_YTMUSICAPI = True
except ImportError:  # bare system-Python fallbacks may lack it
    YTMusic = None
    HAS_YTMUSICAPI = False

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
    # print("✅ Successfully imported yt-dlp", file=sys.stderr)
except ImportError as e:
    print(f"❌ Failed to import yt-dlp: {e}", file=sys.stderr)
    YoutubeDL = None
    HAS_YTDLP = False


import sys
import json
import asyncio
import logging
import traceback  # Add traceback for better error reporting
from typing import Dict, List, Any, Optional
try:
    from ytmusicapi import YTMusic
    HAS_YTMUSICAPI = True
except ImportError:  # bare system-Python fallbacks may lack it
    YTMusic = None
    HAS_YTMUSICAPI = False

# Import yt-dlp with error handling
try:
    from yt_dlp import YoutubeDL
    HAS_YTDLP = True
    # print("✅ Successfully imported yt-dlp", file=sys.stderr)
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

GEMINI_MODEL_NAME = "gemini-2.5-flash-lite"
GEMINI_API_URL_TEMPLATE = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
GEMINI_TIMEOUT_SECONDS = 20

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
        self.base_url = "https://saavn.sumit.co/api"
        
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
                pass
                # print(f"Error searching songs: {e}", file=sys.stderr)
            
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
                pass
                # print(f"Error searching albums: {e}", file=sys.stderr)
            
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
                pass
                # print(f"Error searching artists: {e}", file=sys.stderr)
            
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
                pass
                # print(f"Error searching playlists: {e}", file=sys.stderr)
            
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
                'playCount': str(song.get('playCount', '')) if song.get('playCount') else None,
                'musicSource': 'jiosaavn'  # IMPORTANT: Tag this as JioSaavn
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
                pass
                # print(f"Error searching albums: {e}", file=sys.stderr)
            
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
                pass
                # print(f"Error searching artists: {e}", file=sys.stderr)
            
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
                pass
                # print(f"Error searching playlists: {e}", file=sys.stderr)
            
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
                'playCount': str(song.get('playCount', '')) if song.get('playCount') else None,
                'musicSource': 'jiosaavn'  # IMPORTANT: Tag this as JioSaavn
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
            
            # print(f"🎵 Getting stream info for JioSaavn song ID: {video_id}", file=sys.stderr)
            
            # Get song details using the correct endpoint format
            response = requests.get(f"{self.base_url}/songs", params={
                'ids': video_id  # Use 'ids' instead of 'id'
            }, timeout=10)
            
            # print(f"🎵 JioSaavn API response status: {response.status_code}", file=sys.stderr)
            
            if response.status_code != 200:
                # Try alternative endpoint format
                try:
                    response = requests.get(f"{self.base_url}/songs/{video_id}", timeout=10)
                    # print(f"🎵 Alternative endpoint response: {response.status_code}", file=sys.stderr)
                except Exception as e:
                    pass
                    # print(f"🎵 Alternative endpoint failed: {e}", file=sys.stderr)
                
                if response.status_code != 200:
                    return {
                        'success': False,
                        'error': f'Failed to fetch song details: HTTP {response.status_code}'
                    }
            
            data = response.json()
            # print(f"🎵 JioSaavn API response data keys: {list(data.keys()) if isinstance(data, dict) else f'List with {len(data)} items' if isinstance(data, list) else type(data)}", file=sys.stderr)
            
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
            # print(f"🎵 Song data keys: {list(song_data.keys()) if isinstance(song_data, dict) else f'Type: {type(song_data)}'}", file=sys.stderr)
            
            # Get stream URLs - JioSaavn provides multiple quality options
            download_url = ''
            quality = 'unknown'
            
            # Try to get the highest quality download URL
            if song_data.get('downloadUrl'):
                download_urls = song_data['downloadUrl']
                
                # Handle both dictionary and list formats  
                if isinstance(download_urls, dict):
                    # print(f"🎵 Available download qualities (dict): {list(download_urls.keys())}", file=sys.stderr)
                    # Prefer 320kbps, then 160kbps, then 96kbps, then 48kbps
                    for qual in ['320kbps', '160kbps', '96kbps', '48kbps']:
                        if download_urls.get(qual):
                            download_url = download_urls[qual]
                            quality = qual
                            # print(f"🎵 Selected quality: {quality}", file=sys.stderr)
                            break
                elif isinstance(download_urls, list) and len(download_urls) > 0:
                    # If it's a list of objects with quality and url properties (new API format)
                    # print(f"🎵 Download URLs list format, {len(download_urls)} options available", file=sys.stderr)
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
                                    # print(f"🎵 Found better quality: {quality_str}", file=sys.stderr)
                        elif isinstance(url_info, str):
                            # Fallback for direct URL strings
                            if best_url is None:
                                best_url = url_info
                                best_quality = 'unknown'
                    
                    if best_url:
                        download_url = best_url
                        quality = best_quality
                        # print(f"🎵 Selected URL from list: {quality}", file=sys.stderr)
                else:
                    pass
                    # print(f"🎵 Unexpected downloadUrl format: {type(download_urls)}", file=sys.stderr)
            else:
                # Check for alternative field names
                for field in ['media_url', 'stream_url', 'url', 'link']:
                    if song_data.get(field):
                        download_url = song_data[field]
                        quality = 'default'
                        # print(f"🎵 Using alternative field '{field}' for stream URL", file=sys.stderr)
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
    
    def get_lyrics(self, video_id: str, track_title: str = None, artist_name: str = None) -> Dict[str, Any]:
        """Synced lyrics via LRCLIB first, then JioSaavn's native (plain) lyrics."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            song_data = None
            response = requests.get(f"{self.base_url}/songs", params={
                'ids': video_id
            }, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data.get('success') and data.get('data'):
                    songs = data['data'] if isinstance(data['data'], list) else [data['data']]
                    song_data = songs[0] if songs else None

            title = track_title or (song_data or {}).get('name') or (song_data or {}).get('title') or ''
            artist = artist_name or (song_data or {}).get('primaryArtists') or ''
            if isinstance(artist, list):
                artist = ', '.join(a for a in artist if a)
            artist = (artist or '').split(',')[0].strip()

            # This API mirror exposes no lyrics text of its own, so LRCLIB
            # (synced when available) is the lyrics source for JioSaavn too.
            result = fetch_lrclib_lyrics(title, artist)
            if result:
                return result

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

    def get_home(self) -> Dict[str, Any]:
        """Get JioSaavn home feed with trending songs, playlists, etc."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            # print("🏠 Fetching JioSaavn home feed...", file=sys.stderr)
            
            sections = []
            
            # Try to get modules endpoint first
            try:
                response = requests.get(f"{self.base_url}/modules", params={
                    'language': 'hindi,english'
                }, timeout=15)
                
                if response.status_code == 200:
                    data = response.json()
                    if data.get('success') and data.get('data'):
                        home_data = data['data']
                        
                        # Process trending songs
                        if home_data.get('trending') and home_data['trending'].get('songs'):
                            trending_songs = []
                            for song in home_data['trending']['songs'][:20]:
                                formatted_song = self._format_jiosaavn_song(song)
                                if formatted_song:
                                    trending_songs.append(formatted_song)
                            if trending_songs:
                                sections.append({
                                    'title': 'Trending Now',
                                    'contents': trending_songs
                                })
                        
                        # Process new releases
                        if home_data.get('new_releases'):
                            new_releases = []
                            for album in home_data['new_releases'][:15]:
                                formatted_album = self._format_jiosaavn_album(album)
                                if formatted_album:
                                    new_releases.append(formatted_album)
                            if new_releases:
                                sections.append({
                                    'title': 'New Releases',
                                    'contents': new_releases
                                })
            except Exception as e:
                print(f"⚠️ Modules endpoint failed: {e}, using fallback", file=sys.stderr)
            
            # Fallback: Use search to get trending content if modules failed
            if not sections:
                # print("🔄 Using search fallback for home sections", file=sys.stderr)
                
                # Trending songs
                try:
                    response = requests.get(f"{self.base_url}/search/songs", params={
                        'query': 'trending hits 2024',
                        'page': 0,
                        'limit': 20
                    }, timeout=10)
                    if response.status_code == 200:
                        data = response.json()
                        if data.get('success') and data.get('data'):
                            trending_songs = []
                            for song in data['data'].get('results', [])[:20]:
                                formatted_song = self._format_jiosaavn_song(song)
                                if formatted_song:
                                    trending_songs.append(formatted_song)
                            if trending_songs:
                                sections.append({
                                    'title': 'Trending Now',
                                    'contents': trending_songs
                                })
                except Exception as e:
                    print(f"⚠️ Trending search failed: {e}", file=sys.stderr)
                
                # New releases / Latest
                try:
                    response = requests.get(f"{self.base_url}/search/songs", params={
                        'query': 'new songs 2024',
                        'page': 0,
                        'limit': 15
                    }, timeout=10)
                    if response.status_code == 200:
                        data = response.json()
                        if data.get('success') and data.get('data'):
                            new_songs = []
                            for song in data['data'].get('results', [])[:15]:
                                formatted_song = self._format_jiosaavn_song(song)
                                if formatted_song:
                                    new_songs.append(formatted_song)
                            if new_songs:
                                sections.append({
                                    'title': 'New Releases',
                                    'contents': new_songs
                                })
                except Exception as e:
                    print(f"⚠️ New releases search failed: {e}", file=sys.stderr)
                
                # Bollywood hits
                try:
                    response = requests.get(f"{self.base_url}/search/songs", params={
                        'query': 'bollywood hits',
                        'page': 0,
                        'limit': 15
                    }, timeout=10)
                    if response.status_code == 200:
                        data = response.json()
                        if data.get('success') and data.get('data'):
                            bollywood_songs = []
                            for song in data['data'].get('results', [])[:15]:
                                formatted_song = self._format_jiosaavn_song(song)
                                if formatted_song:
                                    bollywood_songs.append(formatted_song)
                            if bollywood_songs:
                                sections.append({
                                    'title': 'Bollywood Hits',
                                    'contents': bollywood_songs
                                })
                except Exception as e:
                    print(f"⚠️ Bollywood search failed: {e}", file=sys.stderr)
                
                # Punjabi hits
                try:
                    response = requests.get(f"{self.base_url}/search/songs", params={
                        'query': 'punjabi hits',
                        'page': 0,
                        'limit': 15
                    }, timeout=10)
                    if response.status_code == 200:
                        data = response.json()
                        if data.get('success') and data.get('data'):
                            punjabi_songs = []
                            for song in data['data'].get('results', [])[:15]:
                                formatted_song = self._format_jiosaavn_song(song)
                                if formatted_song:
                                    punjabi_songs.append(formatted_song)
                            if punjabi_songs:
                                sections.append({
                                    'title': 'Punjabi Hits',
                                    'contents': punjabi_songs
                                })
                except Exception as e:
                    print(f"⚠️ Punjabi search failed: {e}", file=sys.stderr)
            
            # print(f"🏠 Retrieved {len(sections)} home sections", file=sys.stderr)
            
            return {
                'success': True,
                'data': sections
            }
            
        except Exception as e:
            logger.error(f"JioSaavn home feed failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_charts(self, country: str = 'IN') -> Dict[str, Any]:
        """Get JioSaavn charts/top songs"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            # print(f"📊 Fetching JioSaavn charts...", file=sys.stderr)
            
            # Search for trending songs as charts fallback
            response = requests.get(f"{self.base_url}/search/songs", params={
                'query': 'top hits',
                'page': 0,
                'limit': 50
            }, timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch charts: HTTP {response.status_code}'
                }
            
            data = response.json()
            songs = []
            
            if data.get('success') and data.get('data'):
                for song in data['data'].get('results', [])[:50]:
                    formatted_song = self._format_jiosaavn_song(song)
                    if formatted_song:
                        songs.append(formatted_song)
            
            # print(f"📊 Retrieved {len(songs)} chart songs", file=sys.stderr)
            
            return {
                'success': True,
                'data': {
                    'songs': songs,
                    'videos': [],
                    'artists': [],
                    'trending': []
                }
            }
            
        except Exception as e:
            logger.error(f"JioSaavn charts failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_mood_categories(self) -> Dict[str, Any]:
        """Get JioSaavn mood/genre categories"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            # print("🎭 Fetching JioSaavn mood categories...", file=sys.stderr)
            
            # Define common moods/genres for JioSaavn
            categories = {
                'Moods': [
                    {'title': 'Happy', 'params': 'happy'},
                    {'title': 'Sad', 'params': 'sad'},
                    {'title': 'Romantic', 'params': 'romantic'},
                    {'title': 'Party', 'params': 'party'},
                    {'title': 'Chill', 'params': 'chill'},
                    {'title': 'Workout', 'params': 'workout'},
                    {'title': 'Sleep', 'params': 'sleep'},
                    {'title': 'Focus', 'params': 'focus'}
                ],
                'Genres': [
                    {'title': 'Bollywood', 'params': 'bollywood'},
                    {'title': 'Pop', 'params': 'pop'},
                    {'title': 'Rock', 'params': 'rock'},
                    {'title': 'Hip-Hop', 'params': 'hip hop'},
                    {'title': 'Classical', 'params': 'classical'},
                    {'title': 'Devotional', 'params': 'devotional'},
                    {'title': 'Punjabi', 'params': 'punjabi'},
                    {'title': 'EDM', 'params': 'edm'}
                ]
            }
            
            return {
                'success': True,
                'data': categories
            }
            
        except Exception as e:
            logger.error(f"JioSaavn mood categories failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_mood_playlists(self, params: str) -> Dict[str, Any]:
        """Get JioSaavn playlists for a specific mood/genre"""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }
            
            # print(f"🎭 Fetching JioSaavn playlists for mood: {params}", file=sys.stderr)
            
            # Search for playlists matching the mood
            response = requests.get(f"{self.base_url}/search/songs", params={
                'query': params,
                'page': 0,
                'limit': 30
            }, timeout=10)
            
            if response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch mood playlists: HTTP {response.status_code}'
                }
            
            data = response.json()
            songs = []
            
            if data.get('success') and data.get('data'):
                for song in data['data'].get('results', [])[:30]:
                    formatted_song = self._format_jiosaavn_song(song)
                    if formatted_song:
                        songs.append(formatted_song)
            
            # print(f"🎭 Retrieved {len(songs)} mood songs", file=sys.stderr)
            
            return {
                'success': True,
                'data': songs
            }
            
        except Exception as e:
            logger.error(f"JioSaavn mood playlists failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

# MARK: - LRCLIB synced lyrics (shared by every provider)
#
# LRCLIB (https://lrclib.net) is a free, open lyrics database carrying LRC
# timed lyrics for most commercial music, no API key needed. Every music
# source layers it over its native lyrics: /api/get gives an exact match when
# title/artist/duration are known, /api/search is the fuzzy fallback.

def parse_lrc(lrc_text: str) -> list:
    """Parse LRC format into a list of {time, text} objects."""
    import re
    lines = []
    pattern = re.compile(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)')
    for line in lrc_text.strip().split('\n'):
        match = pattern.match(line.strip())
        if match:
            minutes = int(match.group(1))
            seconds = int(match.group(2))
            centiseconds = match.group(3)
            # Handle both .xx and .xxx formats
            ms = int(centiseconds) * (10 if len(centiseconds) == 2 else 1)
            time_seconds = minutes * 60 + seconds + ms / 1000.0
            lines.append({
                'time': round(time_seconds, 3),
                'text': match.group(4).strip()
            })
    return lines


def _lrclib_request(path: str, params: Dict[str, str]) -> Optional[Any]:
    """GET lrclib.net; None on 404/network trouble."""
    import urllib.request
    import urllib.parse
    url = f"https://lrclib.net{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={
        'User-Agent': 'Izzy Music Player v1.5 (https://github.com/ShubhamPP04/Izzy)'
    })
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        logger.error(f"LRCLIB request failed: {e.code} {path}")
        return None
    except Exception as e:
        logger.error(f"LRCLIB request failed: {e}")
        return None


def fetch_lrclib_lyrics(track: str, artist: str,
                        album: str = None, duration: float = None) -> Optional[Dict[str, Any]]:
    """Synced lyrics for a track, tolerating fuzzy metadata.

    Returns {'success': True, 'data': {lyrics, source, syncedLyrics}} where
    syncedLyrics is [{time, text}] or None for plain lyrics.
    """
    if not track or not artist:
        return None

    params = {'track_name': track, 'artist_name': artist}
    if album:
        params['album_name'] = album
    if duration and duration > 0:
        params['duration'] = str(int(round(duration)))

    def pick(candidates):
        """Best candidate: has real synced lyrics, duration nearest the track."""
        usable = [c for c in candidates
                  if isinstance(c, dict)
                  and (c.get('syncedLyrics') or (c.get('plainLyrics') or '').strip())]

        def score(item):
            has_sync = 1 if item.get('syncedLyrics') else 0
            if duration and item.get('duration'):
                closeness = -abs(float(item['duration']) - float(duration))
            else:
                closeness = 0.0
            return (has_sync, closeness)

        return max(usable, key=score, default=None)

    data = pick([_lrclib_request('/api/get', params) or []])

    # Exact match missing (or junk) - fuzzy search on title+artist, then on a
    # free-form query, which copes with multi-artist metadata like
    # "Mithoon, Arijit Singh".
    if not data:
        data = pick(_lrclib_request('/api/search', params) or [])
    if not data:
        data = pick(_lrclib_request('/api/search', {
            'q': f"{track} {artist}"
        }) or [])

    if not data:
        return None

    synced_raw = data.get('syncedLyrics')
    plain = data.get('plainLyrics') or ''

    # Quality guard: LRCLIB carries junk entries (e.g. a single line reading
    # "probe") and instrumental placeholders with no text at all. Treat
    # anything too short to be real lyrics as a miss so callers fall back to
    # their native lyrics source.
    synced_lines = parse_lrc(synced_raw) if synced_raw else []
    if synced_lines and (len(synced_lines) < 2 or all(not l['text'] for l in synced_lines)):
        synced_raw, synced_lines = None, []
    if not synced_raw and len(plain.strip()) < 20:
        return None

    if synced_raw:
        return {
            'success': True,
            'data': {
                'lyrics': plain or synced_raw,
                'source': 'LRCLIB (Synced)',
                'syncedLyrics': synced_lines
            }
        }
    if plain:
        return {
            'success': True,
            'data': {
                'lyrics': plain,
                'source': 'LRCLIB',
                'syncedLyrics': None
            }
        }
    return None


# MARK: - Tidal Service (via Monochrome)

class TidalService:
    """
    Tidal catalogue through the Monochrome player's API (2026-09 resolution chain).

    The music underneath is Tidal, but every call goes through Monochrome's own
    hosts - we never touch Tidal directly:

      1. PRIMARY - metadata AND audio: https://tracks.monochrome.st
           /search?q=                 tracks / releases / artists / playlists
           /releases/<releaseId>      album with full track list (incl. ISRCs)
           /artists/<artistId>        artist metadata
           /track/<trackId>           direct FLAC stream (proxied, CORS-open,
                                      range-capable, immutable CDN cache)
           /proxy/mi/<cover>.jpg      artwork (640x640 JPEG)
      2. POOL FALLBACK - legacy hifi-api instances, fail over on 429/401/5xx.
         Their /track/ answers JSON or DASH manifests; DASH is rewritten into
         an HLS media playlist for AVPlayer below, which keeps Hi-Res and
         Dolby Atmos alive whenever the pool is reachable.
      3. DEEZER LAST RESORT - https://dzr.tabs-vs-spaces.wtf/stream/
         ?isrc=<isrc>&format=FLAC with Origin: https://monochrome.tf, for
         tracks Monochrome cannot stream when their ISRC is known (stashed
         from search results / album track lists).

    NOTE: tracks.monochrome.st answers default python-requests / urllib user
    agents with 403 - keep the browser User-Agent on every request, including
    stream probes. AVPlayer's AppleCoreMedia agent is accepted.
    """

    PRIMARY_API = "https://tracks.monochrome.st"
    DEEZER_STREAM_URL = "https://dzr.tabs-vs-spaces.wtf/stream/"
    DEEZER_ORIGIN = "https://monochrome.tf"

    # Tiers ascending, used to build the pool attempt order: preferred, then
    # higher, then lower - so a CD-only master still plays when Max is requested.
    QUALITY_TIERS_ASCENDING = ['LOW', 'HIGH', 'LOSSLESS', 'HI_RES_LOSSLESS']

    # Circuit breaker for the legacy pool: after one full failed round, stop
    # dialling it for a while. Class-level because the service process is
    # long-lived but handle_request() builds a fresh instance per call.
    _pool_dead_until = 0.0

    def __init__(self, preferred_quality: Optional[str] = None, dolby_atmos: bool = False,
                 custom_api_url: Optional[str] = None, api_key: Optional[str] = None):
        # Legacy hifi-api streaming pool - failover only, the primary API above
        # is where search and streams come from. Ordered by weight like the
        # Monochrome client does; a user-supplied hifi-api compatible instance
        # (Settings > Tidal) goes first.
        self.api_targets = [
            {"name": "arran", "url": "https://arran.monochrome.tf", "weight": 10},
            {"name": "triton", "url": "https://triton.squid.wtf", "weight": 8},
            {"name": "p1nkhamster", "url": "https://hifi.p1nkhamster.xyz", "weight": 6},
            {"name": "wolf", "url": "https://wolf.qqdl.site", "weight": 2},
            {"name": "maus", "url": "https://maus.qqdl.site", "weight": 2},
            {"name": "vogel", "url": "https://vogel.qqdl.site", "weight": 2},
            {"name": "katze", "url": "https://katze.qqdl.site", "weight": 2},
            {"name": "hund", "url": "https://hund.qqdl.site", "weight": 2},
        ]
        custom_api_url = (custom_api_url or '').strip().rstrip('/')
        if custom_api_url.startswith('http://') or custom_api_url.startswith('https://'):
            self.api_targets.insert(0, {"name": "custom", "url": custom_api_url, "weight": 100})
        self.api_key = (api_key or '').strip()
        self.current_api_index = 0
        self.base_url = self.api_targets[0]["url"]

        # Preferred quality tier (Settings > Tidal). HI_RES_LOSSLESS = up to 24-bit/192kHz.
        quality = (preferred_quality or 'HI_RES_LOSSLESS').upper()
        self.preferred_quality = quality if quality in self.QUALITY_TIERS_ASCENDING else 'HI_RES_LOSSLESS'
        self.dolby_atmos = bool(dolby_atmos)

        # Cache for pool requests only (2 minutes - shorter to avoid stale responses)
        self._cache = {}
        self._cache_ttl = 120

        # Reuse session for connection pooling (reduces CPU/memory)
        self._session = None

    # trackId -> {title, artist, isrc, duration, artistIds} stashed from
    # search results and album track lists. Feeds titles/ISRCs to stream
    # resolution outside search flows (Deezer fallback, artist radio).
    # Class-level because handle_request() builds a fresh instance per call
    # while the service process stays alive across requests.
    _meta: Dict[str, Dict] = {}
    _meta_order: List[str] = []

    # MARK: - HTTP plumbing

    def _get_session(self):
        """Get or create a reusable requests session"""
        if self._session is None:
            self._session = requests.Session()
            self._session.headers.update({
                # tracks.monochrome.st rejects default python-requests/urllib
                # user agents with 403; a browser UA is required everywhere.
                'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
                'Accept': 'application/json, text/plain, */*'
            })
            if self.api_key:
                self._session.headers['X-API-Key'] = self.api_key
        return self._session

    def _reset_session(self):
        """Reset the session to get fresh connections"""
        if self._session is not None:
            try:
                self._session.close()
            except:
                pass
            self._session = None

    def _primary_get(self, path: str, params: Optional[Dict] = None,
                     timeout: int = 8, headers: Optional[Dict] = None) -> Optional[requests.Response]:
        """GET the primary Monochrome API host. Returns a Response or None."""
        if not HAS_REQUESTS:
            return None
        try:
            url = f"{self.PRIMARY_API}{path}"
            return self._get_session().get(url, params=params, timeout=timeout, headers=headers)
        except requests.exceptions.RequestException as e:
            logger.error(f"Monochrome API request failed: {path}: {e}")
            self._reset_session()
            return None

    def _get_next_api(self) -> str:
        """Rotate to next API endpoint on failure"""
        self.current_api_index = (self.current_api_index + 1) % len(self.api_targets)
        self.base_url = self.api_targets[self.current_api_index]["url"]
        return self.base_url

    def _make_request(self, endpoint: str, params: Dict, timeout: int = 6,
                      use_cache: bool = True, max_targets: Optional[int] = None) -> Optional[requests.Response]:
        """Make a pool request with automatic failover on 429/401/5xx.

        `max_targets` caps how many hosts one call may walk (kept small for
        optional paths like Atmos manifests so a dead pool cannot stall a
        request for tens of seconds)."""
        # Circuit breaker: pool recently failed a full round.
        if time.time() < TidalService._pool_dead_until:
            return None

        # Check cache first
        cache_key = self._get_cache_key(endpoint, params)
        if use_cache:
            cached = self._get_cached(cache_key)
            if cached:
                # Return a mock response with cached data
                class CachedResponse:
                    status_code = 200
                    def json(self):
                        return cached
                return CachedResponse()

        last_error = None
        tried_apis = set()
        session = self._get_session()
        target_budget = max_targets if max_targets else len(self.api_targets)

        while len(tried_apis) < len(self.api_targets) and len(tried_apis) < target_budget:
            try:
                url = f"{self.base_url}{endpoint}"
                response = session.get(url, params=params, timeout=timeout)
                if response.status_code == 200:
                    TidalService._pool_dead_until = 0.0  # pool is alive again
                    # Only cache responses that have actual data
                    if use_cache:
                        try:
                            resp_data = response.json()
                            # Only cache if there's actual data
                            if resp_data.get('data') and resp_data['data'].get('items'):
                                self._set_cache(cache_key, resp_data)
                        except:
                            pass
                    return response
                elif response.status_code in [401, 429, 500, 502, 503, 504]:
                    # Rate limited / unauthorized / server error, try next API
                    tried_apis.add(self.base_url)
                    self._get_next_api()
                else:
                    return response  # Return non-failover errors for handling
            except (requests.exceptions.Timeout, requests.exceptions.ConnectionError) as e:
                last_error = e
                tried_apis.add(self.base_url)
                self._get_next_api()
                # Reset session on connection issues to get fresh connection
                self._reset_session()
            except Exception as e:
                last_error = e
                tried_apis.add(self.base_url)
                self._get_next_api()
                # Reset session on any error
                self._reset_session()

        # All APIs failed - reset session, clear cache, and trip the breaker so
        # the next few requests skip the dead pool entirely.
        print(f"❌ All Tidal pool endpoints failed. Last error: {last_error}", file=sys.stderr)
        self._reset_session()
        self._cache.clear()
        TidalService._pool_dead_until = time.time() + 300
        return None

    def _get_cache_key(self, endpoint: str, params: Dict) -> str:
        """Generate cache key"""
        return f"{endpoint}:{json.dumps(params, sort_keys=True)}"

    def _get_cached(self, key: str) -> Optional[Dict]:
        """Get cached response if valid"""
        if key in self._cache:
            cached_time, data = self._cache[key]
            if time.time() - cached_time < self._cache_ttl:
                return data
            else:
                del self._cache[key]  # Remove expired
        return None

    def _set_cache(self, key: str, data: Dict):
        """Cache response data"""
        # Limit cache size to prevent memory issues - max 30 entries
        if len(self._cache) > 30:
            # Remove oldest entries - keep only 15
            oldest_keys = sorted(self._cache.keys(), key=lambda k: self._cache[k][0])[:15]
            for k in oldest_keys:
                del self._cache[k]
        self._cache[key] = (time.time(), data)

    # MARK: - Track metadata stash

    def _stash_meta(self, track: Dict):
        """Remember title/artist/ISRC/duration from a search or release track
        so stream resolution can label the track and reach the Deezer fallback."""
        try:
            track_id = str(track.get('trackId') or track.get('id') or '')
            if not track_id:
                return
            names = track.get('artistNames')
            if not names:
                names = [a.get('name', '') for a in (track.get('artists') or []) if a.get('name')]
            duration_raw = track.get('duration') or 0
            # This API reports durations in milliseconds
            duration = duration_raw / 1000.0 if duration_raw > 10000 else float(duration_raw)
            self._meta[track_id] = {
                'title': track.get('title', ''),
                'artist': ', '.join(n for n in names if n),
                'isrc': track.get('isrc') or '',
                'duration': duration,
                'artistIds': [str(i) for i in (track.get('artistIds') or [])],
            }
            self._meta_order.append(track_id)
            if len(self._meta_order) > 600:
                for old_id in self._meta_order[:200]:
                    self._meta.pop(old_id, None)
                del self._meta_order[:200]
        except Exception:
            pass

    def _meta_for(self, track_id) -> Dict:
        return self._meta.get(str(track_id)) or {}

    # MARK: - Search (primary Monochrome API)

    def search_all(self, query: str, limit: int = 20) -> Dict[str, Any]:
        """
        Search across the Tidal catalogue via tracks.monochrome.st, which
        natively returns tracks, releases (albums), artists and playlists.
        """
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available - Tidal search not supported'
                }

            results = {
                'songs': [],
                'albums': [],
                'artists': [],
                'playlists': [],
                'videos': []
            }

            response = self._primary_get('/search', {'q': query}, timeout=8)
            if response is not None and response.status_code == 200:
                data = response.json()

                for track in (data.get('tracks') or []):
                    if len(results['songs']) >= limit:
                        break
                    if not track.get('playable', True):
                        continue  # Monochrome marks unstreamable tracks
                    formatted_track = self._format_monochrome_track(track)
                    if formatted_track:
                        results['songs'].append(formatted_track)

                for release in (data.get('releases') or []):
                    if len(results['albums']) >= limit:
                        break
                    formatted_album = self._format_monochrome_release(release)
                    if formatted_album:
                        results['albums'].append(formatted_album)

                for artist in (data.get('artists') or []):
                    if len(results['artists']) >= limit:
                        break
                    formatted_artist = self._format_monochrome_artist(artist)
                    if formatted_artist:
                        results['artists'].append(formatted_artist)

                for playlist in (data.get('playlists') or []):
                    if len(results['playlists']) >= limit:
                        break
                    formatted_playlist = self._format_monochrome_playlist(playlist)
                    if formatted_playlist:
                        results['playlists'].append(formatted_playlist)

                if (results['songs'] or results['albums']
                        or results['artists'] or results['playlists']):
                    return {'success': True, 'data': results}

            # Primary unreachable or empty - try the legacy pool before giving up.
            return self._search_pool(query, limit)

        except Exception as e:
            logger.error(f"Tidal search failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def _search_pool(self, query: str, limit: int = 20) -> Dict[str, Any]:
        """Legacy hifi-api search fallback (pool instances)."""
        try:
            results = {
                'songs': [],
                'albums': [],
                'artists': [],
                'playlists': [],
                'videos': []
            }
            seen_albums = set()
            seen_artists = set()

            response = self._make_request("/search/", {'s': query}, timeout=6)
            if response and response.status_code == 200:
                data = response.json()
                items = []
                if data.get('data'):
                    items = data['data'].get('items', [])
                elif data.get('items'):
                    items = data['items']
                elif isinstance(data, list):
                    items = data

                for track in items[:limit * 2]:
                    formatted_track = self._format_tidal_track(track)
                    if formatted_track and len(results['songs']) < limit:
                        results['songs'].append(formatted_track)

                    album_data = track.get('album', {})
                    if album_data and album_data.get('id'):
                        album_id = str(album_data.get('id'))
                        if album_id not in seen_albums and len(results['albums']) < limit:
                            seen_albums.add(album_id)
                            formatted_album = self._format_tidal_album(album_data)
                            if formatted_album:
                                results['albums'].append(formatted_album)

                    artist_data = track.get('artist', {})
                    if artist_data and artist_data.get('id'):
                        artist_id = str(artist_data.get('id'))
                        if artist_id not in seen_artists and len(results['artists']) < limit:
                            seen_artists.add(artist_id)
                            formatted_artist = self._format_tidal_artist(artist_data)
                            if formatted_artist:
                                results['artists'].append(formatted_artist)

                    for artist in track.get('artists', []):
                        if artist and artist.get('id'):
                            artist_id = str(artist.get('id'))
                            if artist_id not in seen_artists and len(results['artists']) < limit:
                                seen_artists.add(artist_id)
                                formatted_artist = self._format_tidal_artist(artist)
                                if formatted_artist:
                                    results['artists'].append(formatted_artist)

            return {
                'success': True,
                'data': results
            }
        except Exception as e:
            logger.error(f"Tidal pool search failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def load_more_songs(self, query: str, offset: int = 0, limit: int = 20) -> Dict[str, Any]:
        """The primary search endpoint ignores offset/limit parameters, so
        pagination is not available - report no more results."""
        return {
            'success': True,
            'data': {
                'songs': [],
                'hasMore': False
            }
        }

    # MARK: - Formatters (primary Monochrome shapes)

    @staticmethod
    def _track_artist_names(track: Dict) -> str:
        names = track.get('artistNames')
        if not names:
            names = [a.get('name', '') for a in (track.get('artists') or []) if a.get('name')]
        return ', '.join(n for n in names if n)

    def _format_monochrome_track(self, track: Dict) -> Optional[Dict]:
        """Format a tracks.monochrome.st track result."""
        try:
            track_id = str(track.get('trackId') or track.get('id') or '')
            self._stash_meta(track)
            duration_ms = track.get('duration') or 0
            return {
                'id': track_id,
                'type': 'songs',
                'title': track.get('title', ''),
                'artist': self._track_artist_names(track),
                'thumbnailURL': track.get('artwork') or '',
                'duration': (duration_ms / 1000.0) or None,
                'explicit': bool(track.get('explicit', False)),
                'videoId': track_id,
                'browseId': None,
                'year': None,
                'playCount': None,
                'musicSource': 'tidal',
                # Monochrome serves the catalogue as lossless FLAC
                'audioQuality': 'LOSSLESS'
            }
        except Exception as e:
            logger.error(f"Error formatting Monochrome track: {e}")
            return None

    def _format_monochrome_release(self, release: Dict) -> Optional[Dict]:
        """Format a tracks.monochrome.st release (album) result."""
        try:
            release_id = str(release.get('releaseId') or release.get('id') or '')
            artist = release.get('artistNames')
            if not artist:
                artist = [a.get('name', '') for a in (release.get('artists') or []) if a.get('name')]
            return {
                'id': release_id,
                'type': 'albums',
                'title': release.get('title', ''),
                'artist': ', '.join(n for n in artist if n),
                'thumbnailURL': release.get('artwork') or '',
                'duration': None,
                'explicit': bool(release.get('explicit', False)),
                'videoId': None,
                'browseId': release_id,
                'year': str(release.get('releaseDate', ''))[:4] or None,
                'playCount': None,
                'musicSource': 'tidal'
            }
        except Exception as e:
            logger.error(f"Error formatting Monochrome release: {e}")
            return None

    def _format_monochrome_artist(self, artist: Dict) -> Optional[Dict]:
        """Format a tracks.monochrome.st artist result."""
        try:
            artist_id = str(artist.get('artistId') or artist.get('id') or '')
            name = artist.get('name') or artist.get('displayName') or ''
            return {
                'id': artist_id,
                'type': 'artists',
                'title': name,
                'artist': name,
                'thumbnailURL': artist.get('avatar') or '',
                'duration': None,
                'explicit': False,
                'videoId': None,
                'browseId': artist_id,
                'year': None,
                'playCount': None,
                'musicSource': 'tidal'
            }
        except Exception as e:
            logger.error(f"Error formatting Monochrome artist: {e}")
            return None

    def _format_monochrome_playlist(self, playlist: Dict) -> Optional[Dict]:
        """Format a tracks.monochrome.st playlist result."""
        try:
            playlist_id = str(playlist.get('playlistId') or playlist.get('id') or '')
            return {
                'id': playlist_id,
                'type': 'playlists',
                'title': playlist.get('title', ''),
                'artist': playlist.get('ownerId') or 'Tidal Playlist',
                'thumbnailURL': '',
                'duration': None,
                'explicit': False,
                'videoId': None,
                'browseId': playlist_id,
                'year': None,
                'playCount': str(playlist.get('trackCount')) if playlist.get('trackCount') else None,
                'musicSource': 'tidal'
            }
        except Exception as e:
            logger.error(f"Error formatting Monochrome playlist: {e}")
            return None

    # MARK: - Formatters (legacy hifi-api shapes, pool fallback)

    def _format_tidal_track(self, track: Dict) -> Optional[Dict]:
        """Format Tidal track result from hifi-api"""
        try:
            # Get cover image URL
            image_url = ''
            album = track.get('album', {})
            cover = album.get('cover')
            if cover:
                slug = cover.replace('-', '/')
                image_url = f"https://resources.tidal.com/images/{slug}/640x640.jpg"

            # Get artist name
            artist_name = ''
            artist = track.get('artist', {})
            if artist:
                artist_name = artist.get('name', '')
            elif track.get('artists') and len(track['artists']) > 0:
                artist_name = ', '.join([a.get('name', '') for a in track['artists'] if a.get('name')])

            # Get audio quality info from track metadata
            audio_quality = track.get('audioQuality', '')
            # Normalize quality names
            if audio_quality in ['HI_RES_LOSSLESS', 'HI_RES', 'LOSSLESS', 'HIGH', 'LOW']:
                pass  # Already normalized
            elif 'MASTER' in str(audio_quality).upper() or 'MQA' in str(audio_quality).upper():
                audio_quality = 'HI_RES_LOSSLESS'
            elif 'HIRES' in str(audio_quality).upper():
                audio_quality = 'HI_RES'

            # Check for HiRes availability from mediaMetadata if present
            media_metadata = track.get('mediaMetadata', {})
            if media_metadata:
                tags = media_metadata.get('tags', [])
                if 'HIRES_LOSSLESS' in tags or 'MQA' in tags:
                    audio_quality = 'HI_RES_LOSSLESS'
                elif 'LOSSLESS' in tags:
                    audio_quality = 'LOSSLESS'

            return {
                'id': str(track.get('id', '')),
                'type': 'songs',
                'title': track.get('title', ''),
                'artist': artist_name,
                'thumbnailURL': image_url,
                'duration': float(track.get('duration', 0)) if track.get('duration') else None,
                'explicit': track.get('explicit', False),
                'videoId': str(track.get('id', '')),  # Use Tidal track ID
                'browseId': None,
                'year': None,
                'playCount': str(track.get('popularity', '')) if track.get('popularity') else None,
                'musicSource': 'tidal',
                'audioQuality': audio_quality if audio_quality else None
            }
        except Exception as e:
            logger.error(f"Error formatting Tidal track: {e}")
            return None

    def _format_tidal_album(self, album: Dict) -> Optional[Dict]:
        """Format Tidal album result from hifi-api"""
        try:
            # Get cover image URL
            image_url = ''
            cover = album.get('cover')
            if cover:
                slug = cover.replace('-', '/')
                image_url = f"https://resources.tidal.com/images/{slug}/640x640.jpg"

            # Get artist name
            artist_name = ''
            artist = album.get('artist', {})
            if artist:
                artist_name = artist.get('name', '')
            elif album.get('artists') and len(album['artists']) > 0:
                artist_name = ', '.join([a.get('name', '') for a in album['artists'] if a.get('name')])

            return {
                'id': str(album.get('id', '')),
                'type': 'albums',
                'title': album.get('title', ''),
                'artist': artist_name,
                'thumbnailURL': image_url,
                'duration': None,
                'explicit': album.get('explicit', False),
                'videoId': None,
                'browseId': str(album.get('id', '')),
                'year': str(album.get('releaseDate', ''))[:4] if album.get('releaseDate') else None,
                'playCount': None,
                'musicSource': 'tidal'
            }
        except Exception as e:
            logger.error(f"Error formatting Tidal album: {e}")
            return None

    def _format_tidal_artist(self, artist: Dict) -> Optional[Dict]:
        """Format Tidal artist result from hifi-api"""
        try:
            # Get cover image URL
            image_url = ''
            picture = artist.get('picture')
            if picture:
                slug = picture.replace('-', '/')
                image_url = f"https://resources.tidal.com/images/{slug}/640x640.jpg"

            return {
                'id': str(artist.get('id', '')),
                'type': 'artists',
                'title': artist.get('name', ''),
                'artist': artist.get('name', ''),
                'thumbnailURL': image_url,
                'duration': None,
                'explicit': False,
                'videoId': None,
                'browseId': str(artist.get('id', '')),
                'year': None,
                'playCount': None,
                'musicSource': 'tidal'
            }
        except Exception as e:
            logger.error(f"Error formatting Tidal artist: {e}")
            return None

    def _format_tidal_playlist(self, playlist: Dict) -> Optional[Dict]:
        """Format Tidal playlist result from hifi-api"""
        try:
            # Get cover image URL
            image_url = ''
            image = playlist.get('image') or playlist.get('squareImage')
            if image:
                slug = image.replace('-', '/')
                image_url = f"https://resources.tidal.com/images/{slug}/640x640.jpg"

            return {
                'id': str(playlist.get('uuid', '')),
                'type': 'playlists',
                'title': playlist.get('title', ''),
                'artist': playlist.get('creator', {}).get('name', 'Tidal Playlist') if playlist.get('creator') else 'Tidal Playlist',
                'thumbnailURL': image_url,
                'duration': None,
                'explicit': False,
                'videoId': None,
                'browseId': str(playlist.get('uuid', '')),
                'year': None,
                'playCount': str(playlist.get('numberOfTracks', '')) if playlist.get('numberOfTracks') else None,
                'musicSource': 'tidal'
            }
        except Exception as e:
            logger.error(f"Error formatting Tidal playlist: {e}")
            return None

    # MARK: - Stream resolution (direct FLAC -> pool DASH -> Deezer fallback)
    #
    # The primary stream is a plain FLAC file at
    #   https://tracks.monochrome.st/track/<trackId>
    # so AVPlayer needs no manifest rewriting for it. The legacy pool path
    # below is kept for Hi-Res / Dolby Atmos: Tidal answers /track/ there in
    # two manifest shapes:
    #   * application/vnd.tidal.bts  -> JSON with a direct file URL (LOSSLESS/HIGH/LOW)
    #   * application/dash+xml       -> segmented DASH (HI_RES_LOSSLESS, and Atmos
    #                                   from /trackManifests/?atmos=true)
    # AVPlayer cannot play DASH, so DASH manifests are rewritten into an HLS media
    # playlist (fMP4 segments are valid HLS media) that Swift serves to AVPlayer.

    def _quality_attempt_order(self, preferred: str) -> List[str]:
        tiers = self.QUALITY_TIERS_ASCENDING
        if preferred not in tiers:
            preferred = 'HI_RES_LOSSLESS'
        index = tiers.index(preferred)
        above = tiers[index + 1:]
        below = list(reversed(tiers[:index]))
        return [preferred] + above + below

    @staticmethod
    def _is_atmos_codec(codec: Optional[str]) -> bool:
        c = (codec or '').strip().lower()
        return c.startswith('ec-3') or c.startswith('eac3') or c.startswith('ac-3') or 'joc' in c

    @staticmethod
    def _is_atmos_manifest(xml_text: str) -> bool:
        lower = (xml_text or '').lower()
        return any(token in lower for token in ('ec-3', 'eac3', 'ec3', 'atmos', 'joc'))

    def _fetch_atmos_manifest_xml(self, track_id: str) -> Optional[str]:
        """Fetch the Dolby Atmos DASH manifest, if the catalogue has an Atmos mix.

        /trackManifests has answered in several JSON shapes (inline XML, base64,
        or a manifest URI nested under data/attributes), so walk them all.
        """
        response = self._make_request("/trackManifests/", {
            'id': track_id,
            'atmos': 'true'
        }, timeout=4, use_cache=False, max_targets=2)
        if not response or response.status_code != 200:
            return None
        try:
            payload = response.json()
        except Exception:
            return None

        found_uri = [None]

        def walk(obj, depth):
            if obj is None or depth > 6:
                return None
            if isinstance(obj, str):
                text = obj.strip()
                if text.startswith('<'):
                    return obj
                if text.startswith('http://') or text.startswith('https://'):
                    if found_uri[0] is None:
                        found_uri[0] = text
                    return None
                if len(text) > 100 and re.fullmatch(r'[A-Za-z0-9+/=\s]+', text):
                    try:
                        decoded = base64.b64decode(text).decode('utf-8')
                        if decoded.strip().startswith('<'):
                            return decoded
                    except Exception:
                        pass
                return None
            if isinstance(obj, list):
                for item in obj:
                    found = walk(item, depth + 1)
                    if found:
                        return found
                return None
            if not isinstance(obj, dict):
                return None
            for key in ('uri', 'url', 'manifestUrl', 'mpdUrl'):
                value = obj.get(key)
                if isinstance(value, str) and value.startswith('http') and found_uri[0] is None:
                    found_uri[0] = value
            for key in ('manifest', 'mpdXml', 'mpd', 'xml', 'mpdBase64', 'manifestBase64'):
                if isinstance(obj.get(key), str):
                    found = walk(obj[key], depth + 1)
                    if found:
                        return found
            for key in ('attributes', 'data', 'included'):
                if isinstance(obj.get(key), (dict, list)):
                    found = walk(obj[key], depth + 1)
                    if found:
                        return found
            return None

        xml_text = walk(payload, 0)
        if xml_text:
            return xml_text
        if found_uri[0]:
            try:
                manifest_response = self._get_session().get(found_uri[0], timeout=6)
                if manifest_response.status_code == 200 and manifest_response.text.strip().startswith('<'):
                    # Relative segment URLs resolve against the manifest URI.
                    return self._inject_base_url(manifest_response.text, found_uri[0])
            except Exception as e:
                logger.error(f"Failed to fetch Atmos manifest URI: {e}")
        return None

    @staticmethod
    def _inject_base_url(xml_text: str, manifest_uri: str) -> str:
        """Remember where a fetched MPD came from so relative URLs can resolve."""
        return f"<!--izzy-base:{manifest_uri}-->" + xml_text

    def _parse_dash_manifest(self, xml_text: str, prefer_atmos: bool = False) -> Optional[Dict[str, Any]]:
        """Parse a DASH MPD into init + media segment URLs with durations.

        Supports SegmentTemplate with SegmentTimeline or a fixed @duration, and a
        single BaseURL file (SegmentBase). Returns None for DRM-protected
        manifests - AVPlayer cannot decrypt Widevine/PlayReady.
        """
        import xml.etree.ElementTree as ET
        from urllib.parse import urljoin

        manifest_uri = ''
        base_marker = re.match(r'<!--izzy-base:(.*?)-->', xml_text)
        if base_marker:
            manifest_uri = base_marker.group(1)
            xml_text = xml_text[base_marker.end():]

        try:
            root = ET.fromstring(xml_text.strip())
        except ET.ParseError as e:
            logger.error(f"Invalid DASH manifest: {e}")
            return None

        def local(tag):
            return tag.split('}', 1)[-1]

        def child(elem, name):
            for c in list(elem):
                if local(c.tag) == name:
                    return c
            return None

        def children(elem, name):
            return [c for c in list(elem) if local(c.tag) == name]

        def join_base(current, elem):
            base = child(elem, 'BaseURL')
            if base is not None and (base.text or '').strip():
                return urljoin(current, base.text.strip())
            return current

        if any(local(e.tag) == 'ContentProtection' for e in root.iter()):
            logger.error("DASH manifest is DRM-protected; cannot play in AVPlayer")
            return None

        def parse_duration(value):
            m = re.match(r'P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?', value or '')
            if not m:
                return 0.0
            days, hours, minutes, seconds = m.groups()
            return (int(days or 0) * 86400 + int(hours or 0) * 3600 +
                    int(minutes or 0) * 60 + float(seconds or 0))

        total_duration = parse_duration(root.get('mediaPresentationDuration'))
        base = join_base(manifest_uri, root)
        period = child(root, 'Period')
        if period is None:
            return None
        base = join_base(base, period)

        # Collect every audio representation with its inherited context.
        candidates = []
        for adaptation in children(period, 'AdaptationSet'):
            mime = (adaptation.get('mimeType') or adaptation.get('contentType') or '')
            if mime and 'audio' not in mime:
                continue
            adaptation_base = join_base(base, adaptation)
            for rep in children(adaptation, 'Representation'):
                codecs = rep.get('codecs') or adaptation.get('codecs') or ''
                candidates.append({
                    'rep': rep,
                    'adaptation': adaptation,
                    'base': join_base(adaptation_base, rep),
                    'codecs': codecs,
                    'bandwidth': int(rep.get('bandwidth') or 0),
                    'sampleRate': int(rep.get('audioSamplingRate') or adaptation.get('audioSamplingRate') or 0),
                })
        if not candidates:
            return None

        def rank(c):
            atmos_bonus = 1 if (prefer_atmos and self._is_atmos_codec(c['codecs'])) else 0
            return (atmos_bonus, c['bandwidth'])

        chosen = max(candidates, key=rank)
        rep, adaptation, rep_base = chosen['rep'], chosen['adaptation'], chosen['base']
        template = child(rep, 'SegmentTemplate')
        if template is None:
            template = child(adaptation, 'SegmentTemplate')

        def fill(pattern, number=None, time_value=None):
            def repl(m):
                name, fmt = m.group(1), m.group(2)
                if name == 'RepresentationID':
                    return rep.get('id') or ''
                if name == 'Bandwidth':
                    value = int(rep.get('bandwidth') or 0)
                elif name == 'Number':
                    value = number or 0
                elif name == 'Time':
                    value = time_value or 0
                else:
                    return m.group(0)
                return (fmt % value) if fmt else str(value)
            filled = re.sub(r'\$(RepresentationID|Number|Time|Bandwidth)(%0\d+d)?\$', repl, pattern)
            return urljoin(rep_base, filled.replace('$$', '$'))

        init_url = None
        segments = []  # (url, seconds)
        if template is not None:
            timescale = int(template.get('timescale') or 1)
            start_number = int(template.get('startNumber') or 1)
            media = template.get('media') or ''
            if template.get('initialization'):
                init_url = fill(template.get('initialization'))
            timeline = child(template, 'SegmentTimeline')
            if timeline is not None:
                number = start_number
                current_time = 0
                for s in children(timeline, 'S'):
                    if s.get('t') is not None:
                        current_time = int(s.get('t'))
                    d = int(s.get('d'))
                    repeat = int(s.get('r') or 0)
                    if repeat < 0 and total_duration > 0:
                        # r="-1": repeat until the end of the period.
                        repeat = max(int((total_duration * timescale - current_time) // d) - 1, 0)
                    for _ in range(repeat + 1):
                        segments.append((fill(media, number, current_time), d / timescale))
                        number += 1
                        current_time += d
            elif template.get('duration') and total_duration > 0:
                seg_seconds = int(template.get('duration')) / timescale
                count = int(-(-total_duration // seg_seconds))  # ceil
                for i in range(count):
                    remaining = total_duration - i * seg_seconds
                    segments.append((fill(media, start_number + i), min(seg_seconds, remaining)))
        elif rep_base:
            # SegmentBase / plain BaseURL: one playable file.
            return {
                'directUrl': rep_base,
                'codec': chosen['codecs'],
                'sampleRate': chosen['sampleRate'],
                'bandwidth': chosen['bandwidth'],
                'duration': total_duration,
            }

        if not segments:
            return None
        if total_duration <= 0:
            total_duration = sum(seconds for _, seconds in segments)
        return {
            'initUrl': init_url,
            'segments': segments,
            'codec': chosen['codecs'],
            'sampleRate': chosen['sampleRate'],
            'bandwidth': chosen['bandwidth'],
            'duration': total_duration,
        }

    @staticmethod
    def _build_hls_playlist(parsed: Dict[str, Any]) -> str:
        """Build a VOD HLS media playlist over the DASH fMP4 segments."""
        import math
        target = max(1, math.ceil(max(seconds for _, seconds in parsed['segments'])))
        lines = [
            '#EXTM3U',
            '#EXT-X-VERSION:7',
            f'#EXT-X-TARGETDURATION:{target}',
            '#EXT-X-MEDIA-SEQUENCE:0',
            '#EXT-X-PLAYLIST-TYPE:VOD',
            '#EXT-X-INDEPENDENT-SEGMENTS',
        ]
        if parsed.get('initUrl'):
            lines.append(f'#EXT-X-MAP:URI="{parsed["initUrl"]}"')
        for url, seconds in parsed['segments']:
            lines.append(f'#EXTINF:{seconds:.6f},')
            lines.append(url)
        lines.append('#EXT-X-ENDLIST')
        return '\n'.join(lines) + '\n'

    @staticmethod
    def _as_int(value) -> Optional[int]:
        try:
            number = int(float(value))
            return number if number > 0 else None
        except (TypeError, ValueError):
            return None

    def _stream_payload_from_dash(self, xml_text: str, prefer_atmos: bool) -> Optional[Dict[str, Any]]:
        parsed = self._parse_dash_manifest(xml_text, prefer_atmos=prefer_atmos)
        if not parsed:
            return None
        if parsed.get('directUrl'):
            return {'url': parsed['directUrl'], 'codec': parsed['codec'],
                    'manifestSampleRate': parsed['sampleRate'], 'bandwidth': parsed['bandwidth']}
        segment_urls = ([parsed['initUrl']] if parsed.get('initUrl') else []) + [u for u, _ in parsed['segments']]
        return {
            'url': segment_urls[0],
            'hlsPlaylist': self._build_hls_playlist(parsed),
            'segmentUrls': segment_urls,
            'codec': parsed['codec'],
            'manifestSampleRate': parsed['sampleRate'],
            'bandwidth': parsed['bandwidth'],
            'manifestDuration': parsed['duration'],
        }

    def _resolve_track_quality(self, track_id: str, quality: str) -> Optional[Dict[str, Any]]:
        """Fetch /track/ at one quality from the pool and turn its manifest
        into a stream payload."""
        response = self._make_request("/track/", {
            'id': track_id,
            'quality': quality
        }, timeout=6, use_cache=False)  # Don't cache stream URLs
        if not response or response.status_code != 200:
            return None
        try:
            track_data = response.json().get('data') or {}
        except Exception:
            return None
        manifest = track_data.get('manifest')
        if not manifest:
            return None
        try:
            decoded_manifest = base64.b64decode(manifest).decode('utf-8')
        except Exception:
            return None
        manifest_type = track_data.get('manifestMimeType', '') or ''

        payload = None
        if 'dash+xml' in manifest_type or decoded_manifest.lstrip().startswith('<'):
            payload = self._stream_payload_from_dash(decoded_manifest, prefer_atmos=False)
        else:
            try:
                manifest_json = json.loads(decoded_manifest)
                urls = manifest_json.get('urls', [])
                if urls:
                    payload = {'url': urls[0], 'codec': manifest_json.get('codecs', '')}
                    if manifest_json.get('encryptionType', 'NONE') not in ('NONE', None, ''):
                        payload = None  # encrypted stream - AVPlayer cannot decode
            except Exception:
                payload = None
        if not payload:
            return None

        payload['audioQuality'] = track_data.get('audioQuality') or quality
        payload['bitDepth'] = self._as_int(track_data.get('bitDepth'))
        payload['sampleRate'] = self._as_int(track_data.get('sampleRate'))
        return payload

    def _resolve_direct_flac(self, track_id: str) -> Optional[Dict[str, Any]]:
        """Resolve the primary Monochrome stream: a direct FLAC file at
        /track/<id>. A 64-byte range fetch validates availability and yields
        the FLAC STREAMINFO header (sample rate, bit depth, exact duration),
        which drives the quality badge - no manifest walk needed."""
        url = f"{self.PRIMARY_API}/track/{track_id}"
        try:
            with self._get_session().get(url, timeout=6, stream=True,
                                         headers={'Range': 'bytes=0-63'}) as response:
                if response.status_code not in (200, 206):
                    return None
                data = b''
                for chunk in response.iter_content(64):
                    data += chunk
                    if len(data) >= 64:
                        break
        except requests.exceptions.RequestException:
            return None

        if len(data) < 42 or data[:4] != b'fLaC':
            return None
        streaminfo = data[8:42]
        sample_rate = (streaminfo[10] << 12) | (streaminfo[11] << 4) | (streaminfo[12] >> 4)
        channels = ((streaminfo[12] >> 1) & 0b111) + 1
        # FLAC stores bits-per-sample minus one
        bit_depth = (((streaminfo[12] & 1) << 4) | (streaminfo[13] >> 4)) + 1
        total_samples = ((streaminfo[13] & 0x0F) << 32) | (streaminfo[14] << 24) | \
                        (streaminfo[15] << 16) | (streaminfo[16] << 8) | streaminfo[17]

        payload = {'url': url, 'codec': 'flac'}
        if 8000 <= sample_rate <= 192000:
            payload['sampleRate'] = sample_rate
            payload['manifestSampleRate'] = sample_rate
            if 4 <= bit_depth <= 32:
                payload['bitDepth'] = bit_depth
            payload['channels'] = channels
            if sample_rate > 0 and total_samples > 0:
                payload['duration'] = total_samples / sample_rate
        return payload

    def _resolve_deezer_fallback(self, track_id: str) -> Optional[Dict[str, Any]]:
        """Last resort: Deezer FLAC by ISRC for tracks Monochrome cannot
        stream. The endpoint only answers requests bearing an allowed Origin
        (Monochrome's own), which we must send ourselves."""
        isrc = self._meta_for(track_id).get('isrc')
        if not isrc:
            return None
        from urllib.parse import quote
        url = f"{self.DEEZER_STREAM_URL}?isrc={quote(isrc)}&format=FLAC"
        try:
            with self._get_session().get(url, timeout=6, stream=True, allow_redirects=True,
                                         headers={
                                             'Origin': self.DEEZER_ORIGIN,
                                             'Referer': f"{self.DEEZER_ORIGIN}/",
                                             'Range': 'bytes=0-63'
                                         }) as response:
                if response.status_code not in (200, 206):
                    logger.error(f"Deezer fallback unavailable: HTTP {response.status_code}")
                    return None
                data = b''
                for chunk in response.iter_content(64):
                    data += chunk
                    if len(data) >= 64:
                        break
        except requests.exceptions.RequestException as e:
            logger.error(f"Deezer fallback failed: {e}")
            return None

        if data[4:8] == b'ftyp':
            codec = 'aac'
        else:
            codec = 'flac'  # format=FLAC; accept opaque streams too
        return {'url': url, 'codec': codec, 'audioQuality': 'LOSSLESS'}

    def _resolve_stream(self, track_id: str, for_download: bool) -> Dict[str, Any]:
        if not HAS_REQUESTS:
            return {
                'success': False,
                'error': 'requests library not available - Tidal streaming not supported'
            }

        payload = None
        is_atmos = False
        source = 'monochrome'

        # Dolby Atmos: a property of the STREAM, never the request. Only report
        # Atmos when the manifest really carries E-AC-3 JOC; otherwise play stereo.
        # Downloads are always stereo lossless.
        if self.dolby_atmos and not for_download:
            atmos_xml = self._fetch_atmos_manifest_xml(track_id)
            if atmos_xml and self._is_atmos_manifest(atmos_xml):
                payload = self._stream_payload_from_dash(atmos_xml, prefer_atmos=True)
                if payload and self._is_atmos_codec(payload.get('codec')):
                    is_atmos = True
                    payload['audioQuality'] = 'DOLBY_ATMOS'
                else:
                    payload = None

        # 1) Primary: direct lossless FLAC from Monochrome's own stream host.
        if payload is None:
            payload = self._resolve_direct_flac(track_id)

        # 2) Pool fallback: legacy hifi-api /track/ (JSON or DASH -> HLS).
        if payload is None:
            source = 'pool'
            for quality in self._quality_attempt_order(self.preferred_quality):
                payload = self._resolve_track_quality(track_id, quality)
                if payload:
                    break

        # 3) Last resort: Deezer by ISRC for tracks Monochrome cannot serve.
        if payload is None:
            payload = self._resolve_deezer_fallback(track_id)
            if payload:
                source = 'deezer'

        if not payload:
            return {
                'success': False,
                'error': 'Failed to get Tidal stream at any quality level'
            }

        meta = self._meta_for(track_id)
        title = meta.get('title') or ''
        duration = meta.get('duration') or 0
        if not duration and payload.get('duration'):
            duration = payload['duration']
        if not duration and payload.get('manifestDuration'):
            duration = payload['manifestDuration']

        # Upstream quality answers can lag the actual master, so trust parsed
        # STREAMINFO over request parameters.
        actual_quality = payload.get('audioQuality') or self.preferred_quality
        sample_rate = payload.get('manifestSampleRate') or payload.get('sampleRate')
        bit_depth = payload.get('bitDepth')
        if is_atmos:
            sample_rate = sample_rate or 48000
            bit_depth = None
        elif source == 'monochrome':
            actual_quality = 'HI_RES_LOSSLESS' if ((bit_depth or 16) > 16 or (sample_rate or 44100) > 48000) else 'LOSSLESS'
        elif actual_quality == 'HI_RES_LOSSLESS' and not bit_depth:
            bit_depth = 24 if (sample_rate or 0) > 48000 else None

        codec = (payload.get('codec') or '').lower()
        if is_atmos:
            quality_info = 'Dolby Atmos (E-AC-3 JOC)'
        elif source == 'deezer':
            quality_info = 'Lossless (FLAC via Deezer fallback)'
        elif bit_depth and sample_rate:
            quality_info = f"{actual_quality} ({bit_depth}-bit/{sample_rate / 1000:.1f}kHz)"
        else:
            quality_info = actual_quality

        if is_atmos:
            mime_type = 'audio/eac3'
        elif payload.get('hlsPlaylist'):
            mime_type = 'audio/mp4'  # fragmented MP4 (FLAC or AAC inside)
        elif 'flac' in codec or source == 'monochrome':
            mime_type = 'audio/flac'
        elif actual_quality in ('HIGH', 'LOW') or 'mp4a' in codec or 'aac' in codec:
            mime_type = 'audio/mp4'
        else:
            mime_type = 'audio/flac'

        data = {
            'url': payload['url'],
            'title': title,
            'duration': int(duration or 0),
            'quality': actual_quality,
            'qualityInfo': quality_info,
            'bitDepth': bit_depth,
            'sampleRate': sample_rate,
            'mimeType': mime_type,
            'codec': codec or None,
            'audioMode': 'DOLBY_ATMOS' if is_atmos else 'STEREO',
        }
        if payload.get('hlsPlaylist'):
            data['hlsPlaylist'] = payload['hlsPlaylist']
            data['segmentUrls'] = payload['segmentUrls']
        elif source in ('monochrome', 'deezer'):
            # These CDNs challenge AVPlayer's UA-less requests (Cloudflare 520
            # -> "Cannot Open"), so Swift relays the bytes through its resource
            # loader with a browser User-Agent.
            data['needsByteProxy'] = True
        return {'success': True, 'data': data}

    def get_stream_info(self, track_id: str) -> Dict[str, Any]:
        """Get Tidal stream info honouring the user's quality and Dolby Atmos settings."""
        try:
            return self._resolve_stream(track_id, for_download=False)
        except Exception as e:
            logger.error(f"Tidal stream extraction failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_stream_info_for_download(self, track_id: str) -> Dict[str, Any]:
        """Get Tidal stream info for downloading (stereo, preferred quality first).

        Segmented (DASH) results carry `segmentUrls`, which the Swift downloader
        concatenates into one fragmented MP4 before remuxing to FLAC.
        """
        try:
            return self._resolve_stream(track_id, for_download=True)
        except Exception as e:
            logger.error(f"Tidal download stream extraction failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    # MARK: - Catalogue (primary Monochrome API)

    def get_album_tracks(self, album_id: str) -> Dict[str, Any]:
        """Album track list from /releases/<id> (includes ISRCs, which we
        stash for the Deezer fallback)."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            response = self._primary_get(f"/releases/{album_id}", timeout=15)
            if not response or response.status_code != 200:
                return {
                    'success': False,
                    'error': f'Failed to fetch album: HTTP {response.status_code if response else "no response"}'
                }

            data = response.json()
            tracks = []
            for track in (data.get('tracks') or []):
                if not track.get('playable', True):
                    continue
                formatted_track = self._format_monochrome_track(track)
                if formatted_track:
                    tracks.append(formatted_track)

            if not tracks:
                return {
                    'success': False,
                    'error': 'Album not found or has no playable tracks'
                }
            return {
                'success': True,
                'data': tracks
            }

        except Exception as e:
            logger.error(f"Tidal album tracks failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_playlist_tracks(self, playlist_id: str) -> Dict[str, Any]:
        """Monochrome exposes no playlist-detail endpoint, so Tidal playlist
        results cannot be expanded yet."""
        return {
            'success': False,
            'error': 'Tidal playlists are not supported by the current Monochrome API'
        }

    def get_artist_songs(self, artist_id: str) -> Dict[str, Any]:
        """Monochrome has no artist-tracks endpoint: resolve the artist name
        via /artists/<id>, then filter a name search by artistIds."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            response = self._primary_get(f"/artists/{artist_id}", timeout=10)
            artist_name = ''
            if response is not None and response.status_code == 200:
                try:
                    artist_name = response.json().get('name') or ''
                except Exception:
                    artist_name = ''
            if not artist_name:
                return {
                    'success': False,
                    'error': 'Artist not found'
                }

            search_result = self.search_all(artist_name, limit=40)
            if not search_result.get('success'):
                return search_result
            songs = search_result.get('data', {}).get('songs', []) or []
            if not songs:
                return {
                    'success': True,
                    'data': []
                }

            own_tracks = [s for s in songs
                          if artist_id in (self._meta_for(s.get('videoId')).get('artistIds') or [])]
            picked = own_tracks if len(own_tracks) >= 3 else songs
            return {
                'success': True,
                'data': picked[:30]
            }

        except Exception as e:
            logger.error(f"Tidal artist songs failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_artist_songs_paginated(self, artist_id: str, offset: int = 0, limit: int = 20) -> Dict[str, Any]:
        """Search-backed artist songs, sliced to the requested page."""
        result = self.get_artist_songs(artist_id)
        if not result.get('success'):
            return result
        songs = result.get('data') or []
        return {
            'success': True,
            'data': songs[offset:offset + limit]
        }

    # MARK: - Radio / suggestions

    def _similar_by_artist(self, track_id: str) -> Dict[str, Any]:
        """Radio-style suggestions: more tracks from the same artist. The
        Monochrome API has no mix endpoint, so this is search-backed and needs
        the track's stashed metadata (i.e. the track came from a search or an
        album view in this session)."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            artist = (self._meta_for(track_id).get('artist') or '').split(',')[0].strip()
            if not artist:
                return {
                    'success': False,
                    'error': 'Could not get track info for suggestions'
                }

            search_result = self.search_all(artist, limit=20)
            if not search_result.get('success'):
                return search_result
            songs = search_result.get('data', {}).get('songs', []) or []
            others = [s for s in songs if str(s.get('videoId')) != str(track_id)]
            if not others:
                return {
                    'success': False,
                    'error': 'No suggestions available'
                }
            return {
                'success': True,
                'data': others
            }

        except Exception as e:
            logger.error(f"Tidal song suggestions failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_watch_playlist(self, track_id: str, playlist_id: str = None) -> Dict[str, Any]:
        """Get similar tracks for the queue (artist-based)."""
        return self._similar_by_artist(track_id)

    def get_song_suggestions(self, track_id: str) -> Dict[str, Any]:
        """Get song suggestions (artist-based)."""
        return self._similar_by_artist(track_id)

    def get_lyrics(self, track_id: str, track_title: str = None, artist_name: str = None) -> Dict[str, Any]:
        """Synced lyrics via LRCLIB - the Monochrome API exposes no lyrics
        endpoint of its own. Title/artist come from Swift or the metadata
        stash; the stashed duration sharpens the match."""
        try:
            meta = self._meta_for(track_id)
            title = track_title or meta.get('title') or ''
            artist = artist_name or (meta.get('artist') or '').split(',')[0].strip()
            duration = meta.get('duration') or 0
            result = fetch_lrclib_lyrics(title, artist, duration=duration)
            if result:
                return result
            return {
                'success': False,
                'error': 'No lyrics found for this song'
            }
        except Exception as e:
            logger.error(f"Tidal lyrics failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    # MARK: - Discovery (search-backed)

    def _quick_track_search(self, query: str, count: int) -> List[Dict[str, Any]]:
        """Formatted primary tracks for curated sections, empty on failure."""
        tracks: List[Dict[str, Any]] = []
        response = self._primary_get('/search', {'q': query}, timeout=10)
        if response is not None and response.status_code == 200:
            try:
                data = response.json()
            except Exception:
                return tracks
            for track in (data.get('tracks') or []):
                if len(tracks) >= count:
                    break
                if not track.get('playable', True):
                    continue
                formatted_track = self._format_monochrome_track(track)
                if formatted_track:
                    tracks.append(formatted_track)
        return tracks

    def get_home(self) -> Dict[str, Any]:
        """Tidal home feed with curated high-quality content."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            curated_sections = [
                {'query': 'hi-res lossless', 'title': '🎧 Hi-Res Lossless'},
                {'query': 'top hits 2024', 'title': '🔥 Top Hits'},
                {'query': 'new releases', 'title': '🆕 New Releases'},
            ]

            sections = []
            for section_info in curated_sections:
                tracks = self._quick_track_search(section_info['query'], 12)
                if len(tracks) >= 3:
                    sections.append({
                        'title': section_info['title'],
                        'contents': tracks
                    })

            return {
                'success': True,
                'data': sections
            }

        except Exception as e:
            logger.error(f"Tidal home feed failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_charts(self, country: str = 'US') -> Dict[str, Any]:
        """Tidal charts (search-backed)."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            songs = self._quick_track_search('top hits', 50)
            return {
                'success': True,
                'data': {
                    'songs': songs,
                    'videos': [],
                    'artists': [],
                    'trending': []
                }
            }

        except Exception as e:
            logger.error(f"Tidal charts failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_mood_categories(self) -> Dict[str, Any]:
        """Get Tidal mood/genre categories"""
        try:
            categories = {
                'Moods': [
                    {'title': 'Happy', 'params': 'happy'},
                    {'title': 'Sad', 'params': 'sad'},
                    {'title': 'Relaxing', 'params': 'relaxing'},
                    {'title': 'Party', 'params': 'party'},
                    {'title': 'Chill', 'params': 'chill'},
                    {'title': 'Workout', 'params': 'workout'},
                    {'title': 'Sleep', 'params': 'sleep'},
                    {'title': 'Focus', 'params': 'focus'}
                ],
                'Genres': [
                    {'title': 'Pop', 'params': 'pop'},
                    {'title': 'Rock', 'params': 'rock'},
                    {'title': 'Hip-Hop', 'params': 'hip hop'},
                    {'title': 'R&B', 'params': 'r&b'},
                    {'title': 'Electronic', 'params': 'electronic'},
                    {'title': 'Classical', 'params': 'classical'},
                    {'title': 'Jazz', 'params': 'jazz'},
                    {'title': 'Country', 'params': 'country'}
                ]
            }

            return {
                'success': True,
                'data': categories
            }

        except Exception as e:
            logger.error(f"Tidal mood categories failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def get_mood_playlists(self, params: str) -> Dict[str, Any]:
        """Playlists for a mood/genre, falling back to matching songs."""
        try:
            if not HAS_REQUESTS:
                return {
                    'success': False,
                    'error': 'requests library not available'
                }

            playlists = []
            response = self._primary_get('/search', {'q': params}, timeout=15)
            if response is not None and response.status_code == 200:
                try:
                    data = response.json()
                except Exception:
                    data = {}
                for playlist in (data.get('playlists') or []):
                    if len(playlists) >= 30:
                        break
                    formatted_playlist = self._format_monochrome_playlist(playlist)
                    if formatted_playlist:
                        playlists.append(formatted_playlist)

            if playlists:
                return {
                    'success': True,
                    'data': playlists
                }

            # Fall back to songs matching the mood
            songs = self._quick_track_search(params, 30)
            if songs:
                return {
                    'success': True,
                    'data': songs
                }

            return {
                'success': False,
                'error': 'Failed to fetch mood playlists'
            }

        except Exception as e:
            logger.error(f"Tidal mood playlists failed: {e}")
            return {
                'success': False,
                'error': str(e)
            }

# MARK: - YouTube Music Service

# 🔋 BATTERY OPTIMIZATION: Check for optional dependencies

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

            # Cache for previously resolved stream URLs to avoid redundant extraction
            self._stream_cache: Dict[str, Dict[str, Any]] = {}
            self._stream_cache_ttl = 300  # seconds
            
            # 🔋 BATTERY OPTIMIZATION: Configure yt-dlp for minimal resource usage
            if HAS_YTDLP:
                self.ydl_opts = {
                    'format': 'bestaudio[ext=m4a][abr<=160]/bestaudio[abr<=160]/bestaudio[ext=m4a]/bestaudio',
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
                    'cachedir': False,
                    'prefer_free_formats': True,
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
                # print(f"Using ytmusicapi for search: {query}", file=sys.stderr)
                results = self._search_with_ytmusicapi(query, limit)
                return {
                    'success': True,
                    'data': results  # Return the MusicSearchResults structure directly
                }
            else:
                # print(f"Using fallback search for: {query}", file=sys.stderr)
                results = self._search_fallback(query, limit)
                return {
                    'success': True,
                    'data': results  # Return the MusicSearchResults structure directly
                }
            
        except Exception as e:
            logger.error(f"Search failed: {e}")
            # print(f"Search error: {e}", file=sys.stderr)
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
                # print(f"Searching {category} for: '{query}' with filter '{filter_name}'", file=sys.stderr)
                
                # Use ytmusicapi search with proper filter
                search_results = self.yt.search(query, filter=filter_name, limit=limit)
                # print(f"Got {len(search_results)} {category} results", file=sys.stderr)
                
                # Format results
                formatted_results = self._format_search_results(search_results, category)
                results[category] = formatted_results
                # print(f"Formatted {len(formatted_results)} {category} results", file=sys.stderr)
                
            except Exception as e:
                logger.error(f"Error searching {category}: {e}")
                # print(f"Error searching {category}: {e}", file=sys.stderr)
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

    def ai_search(self, query: str, limit: int = 15, gemini_api_key: Optional[str] = None) -> Dict[str, Any]:
        """Provide AI-assisted search insights and curated results powered by Gemini."""
        try:
            stripped_query = (query or "").strip()
            if not stripped_query:
                return {
                    'success': False,
                    'error': 'Query is required for AI search'
                }

            suggestions: List[str] = []
            if HAS_YTMUSICAPI and self.yt:
                try:
                    raw_suggestions = self.yt.get_search_suggestions(stripped_query) or []
                    cleaned: List[str] = []
                    for suggestion in raw_suggestions:
                        if isinstance(suggestion, str):
                            cleaned.append(suggestion)
                        elif isinstance(suggestion, dict):
                            text_value = suggestion.get('text') or suggestion.get('query')
                            if text_value:
                                cleaned.append(text_value)
                    suggestions = cleaned[:8]
                except Exception as suggestion_error:
                    logger.warning(f"Failed to load ai suggestions: {suggestion_error}")
                    suggestions = []

            if HAS_YTMUSICAPI and self.yt:
                aggregated_results = self._search_with_ytmusicapi(stripped_query, limit)
            else:
                aggregated_results = self._search_fallback(stripped_query, limit)

            songs = aggregated_results.get('songs', []) or []
            curated = songs[: min(len(songs), 6)]

            insights: List[str] = []
            if curated:
                primary = curated[0]
                title = primary.get('title', 'Top match')
                artist = primary.get('artist')
                insight = f"Top match: {title}"
                if artist:
                    insight += f" • {artist}"
                insights.append(insight)

            artists = aggregated_results.get('artists', []) or []
            if artists:
                artist_name = artists[0].get('title') or artists[0].get('artist')
                if artist_name:
                    insights.append(f"Featured artist: {artist_name}")

            playlists = aggregated_results.get('playlists', []) or []
            if playlists:
                playlist_title = playlists[0].get('title')
                if playlist_title:
                    insights.append(f"Curated playlist: {playlist_title}")

            gemini_enrichment = self._generate_gemini_enrichment(
                stripped_query,
                curated,
                suggestions,
                gemini_api_key
            ) if gemini_api_key else None

            if gemini_enrichment:
                suggestions = self._merge_unique_strings(
                    suggestions,
                    gemini_enrichment.get('suggestions', []),
                    limit=10
                )
                insights = self._merge_unique_strings(
                    insights,
                    gemini_enrichment.get('insights', []),
                    limit=6
                )

            response_payload = {
                'query': stripped_query,
                'suggestions': suggestions,
                'topResults': curated,
                'results': aggregated_results,
                'insights': insights
            }

            return {
                'success': True,
                'data': response_payload
            }

        except Exception as error:
            logger.error(f"AI search failed: {error}")
            logger.error(traceback.format_exc())
            return {
                'success': False,
                'error': str(error)
            }
    
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

    def _generate_gemini_enrichment(
        self,
        query: str,
        curated: List[Dict[str, Any]],
        existing_suggestions: List[str],
        api_key: Optional[str]
    ) -> Optional[Dict[str, List[str]]]:
        if not api_key or not HAS_REQUESTS:
            return None

        try:
            top_lines: List[str] = []
            for index, item in enumerate(curated[:4], start=1):
                title = item.get('title') or 'Unknown title'
                artist = item.get('artist') or 'Unknown artist'
                duration = item.get('duration')
                duration_str = ''
                if isinstance(duration, (int, float)) and duration:
                    mins = int(duration) // 60
                    secs = int(duration) % 60
                    duration_str = f" ({mins}:{secs:02d})"
                top_lines.append(f"{index}. {title} — {artist}{duration_str}")

            prompt = "You are a music curation assistant."
            prompt += "\nQuery: " + query
            if top_lines:
                prompt += "\nTop candidates:\n" + "\n".join(top_lines)
            if existing_suggestions:
                prompt += "\nExisting quick suggestions: " + ", ".join(existing_suggestions[:5])
            prompt += (
                "\n\nReturn strictly JSON with two keys:"
                "\n  \"suggestions\": an array of up to 4 refined search prompts (strings)"
                "\n  \"insights\": an array of up to 4 short bullet insights highlighting themes or artists"
                "\nDo not include any additional text outside the JSON object."
            )

            payload = {
                "contents": [
                    {
                        "role": "user",
                        "parts": [
                            {
                                "text": prompt
                            }
                        ]
                    }
                ],
                "generationConfig": {
                    "temperature": 0.4,
                    "topP": 0.9,
                    "maxOutputTokens": 512,
                    "responseMimeType": "application/json"
                }
            }

            url = GEMINI_API_URL_TEMPLATE.format(model=GEMINI_MODEL_NAME)
            response = requests.post(
                url,
                params={'key': api_key},
                json=payload,
                timeout=GEMINI_TIMEOUT_SECONDS
            )
            response.raise_for_status()
            data = response.json()

            candidates = data.get('candidates') or []
            for candidate in candidates:
                parts = candidate.get('content', {}).get('parts', [])
                combined = "".join(
                    part.get('text', '')
                    for part in parts
                    if isinstance(part, dict)
                ).strip()
                parsed = self._parse_gemini_json(combined)
                if parsed:
                    return parsed

            return None
        except Exception as exc:
            logger.warning(f"Gemini enrichment failed: {exc}")
            # print(f"Gemini enrichment failed: {exc}", file=sys.stderr)
            return None

        @staticmethod
        def _parse_gemini_json(raw_text: str) -> Optional[Dict[str, List[str]]]:
            if not raw_text:
                return None

            try:
                parsed = json.loads(raw_text)
            except json.JSONDecodeError:
                if not HAS_REQUESTS:
                    return None
                match = re.search(r'\{.*\}', raw_text, re.DOTALL)
                if not match:
                    return None
                try:
                    parsed = json.loads(match.group(0))
                except json.JSONDecodeError:
                    return None

            suggestions = [
                str(item).strip()
                for item in parsed.get('suggestions', [])
                if isinstance(item, str) and item.strip()
            ]
            insights = [
                str(item).strip()
                for item in parsed.get('insights', [])
                if isinstance(item, str) and item.strip()
            ]

            return {
                'suggestions': suggestions,
                'insights': insights
            }

        @staticmethod
        def _merge_unique_strings(primary: List[str], extras: List[str], limit: int) -> List[str]:
            result: List[str] = []
            seen = set()

            for value in primary + extras:
                if not isinstance(value, str):
                    continue
                trimmed = value.strip()
                if not trimmed:
                    continue
                key = trimmed.casefold()
                if key in seen:
                    continue
                seen.add(key)
                result.append(trimmed)
                if len(result) >= limit:
                    break

            return result
    
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
                'id': safe_get(item, 'videoId') or safe_get(item, 'playlistId') or safe_get(item, 'browseId', ''),
                'type': category,
                'title': title,
                'artist': None,  # Will be set below based on category
                'thumbnailURL': None,  # Will be set below
                'duration': None,  # Will be set below
                'explicit': safe_get(item, 'isExplicit', False),
                'videoId': safe_get(item, 'videoId'),
                'browseId': safe_get(item, 'browseId'),
                'year': None,  # Will be set below
                'playCount': None,  # Will be set below
                'musicSource': 'youtube_music'  # IMPORTANT: Tag this as YouTube Music
            }
            
            # For playlists, ensure id is set to playlistId
            if category == 'playlists':
                playlist_id = safe_get(item, 'playlistId')
                if playlist_id:
                    result['id'] = playlist_id
                    # print(f"📋 Playlist formatted: {title} with playlistId: {playlist_id}", file=sys.stderr)
            
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

    def _get_cached_stream(self, video_id: str) -> Optional[Dict[str, Any]]:
        cached_entry = self._stream_cache.get(video_id)
        if not cached_entry:
            return None
        if time.time() - cached_entry['timestamp'] > self._stream_cache_ttl:
            self._stream_cache.pop(video_id, None)
            return None
        return cached_entry['data']

    def _set_cached_stream(self, video_id: str, payload: Dict[str, Any]) -> None:
        self._stream_cache[video_id] = {
            'timestamp': time.time(),
            'data': payload
        }
        if len(self._stream_cache) > 64:
            self._cleanup_stream_cache()

    def _cleanup_stream_cache(self) -> None:
        now = time.time()
        expired_keys = [key for key, entry in self._stream_cache.items()
                        if now - entry['timestamp'] > self._stream_cache_ttl]
        for key in expired_keys:
            self._stream_cache.pop(key, None)
    
    def get_stream_info(self, video_id: str) -> Dict[str, Any]:
        """
        Extract stream URL and metadata for a video ID using yt-dlp or fallback
        OPTIMIZED for fast loading - prioritizes speed over quality
        """
        import time
        start_time = time.time()
        
        try:
            # 1. Check cache first (instant)
            cached = self._get_cached_stream(video_id)
            if cached:
                # print(f"⚡ Cached stream in {time.time() - start_time:.2f}s for {video_id}", file=sys.stderr)
                return {
                    'success': True,
                    'data': cached
                }

            # 2. Try fast ytmusicapi extraction first (usually < 1 second)
            # print(f"🚀 Attempting fast stream extraction for {video_id}", file=sys.stderr)
            fast_stream = self._get_stream_via_ytmusicapi(video_id)
            if fast_stream and fast_stream.get('success'):
                self._set_cached_stream(video_id, fast_stream['data'])
                # print(f"⚡ Fast stream in {time.time() - start_time:.2f}s for {video_id}", file=sys.stderr)
                return fast_stream

            # 3. Try Invidious API (fast, no rate limiting)
            # print(f"🔄 Trying Invidious API for {video_id}", file=sys.stderr)
            invidious_stream = self._get_stream_via_invidious(video_id)
            if invidious_stream and invidious_stream.get('success'):
                self._set_cached_stream(video_id, invidious_stream['data'])
                # print(f"⚡ Invidious stream in {time.time() - start_time:.2f}s for {video_id}", file=sys.stderr)
                return invidious_stream

            # 4. Fallback to yt-dlp (slower but more reliable)
            if HAS_YTDLP:
                # print(f"🐢 Falling back to yt-dlp for {video_id}", file=sys.stderr)
                result = self._get_stream_with_ytdlp_fast(video_id)
                if result.get('success'):
                    self._set_cached_stream(video_id, result['data'])
                    # print(f"⚡ yt-dlp stream in {time.time() - start_time:.2f}s for {video_id}", file=sys.stderr)
                return result
            else:
                # print(f"yt-dlp not available, using fallback for: {video_id}", file=sys.stderr)
                return self._get_stream_fallback(video_id)
                
        except Exception as e:
            logger.error(f"Stream extraction failed for {video_id}: {e}")
            return {
                'success': False,
                'error': f"Stream extraction failed: {str(e)}"
            }

    def _get_stream_via_invidious(self, video_id: str) -> Optional[Dict[str, Any]]:
        """Get stream via Invidious API - fast and reliable alternative"""
        try:
            import urllib.request
            import json
            
            # List of Invidious instances to try
            instances = [
                'https://inv.nadeko.net',
                'https://invidious.fdn.fr',
                'https://invidious.privacyredirect.com',
                'https://vid.puffyan.us',
            ]
            
            for instance in instances:
                try:
                    url = f"{instance}/api/v1/videos/{video_id}"
                    req = urllib.request.Request(url, headers={
                        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                    })
                    
                    with urllib.request.urlopen(req, timeout=5) as response:
                        data = json.loads(response.read().decode('utf-8'))
                    
                    # Get audio streams
                    adaptive_formats = data.get('adaptiveFormats', [])
                    audio_formats = [f for f in adaptive_formats if f.get('type', '').startswith('audio/')]
                    
                    if audio_formats:
                        # Prefer m4a/mp4 audio, then webm
                        best_audio = None
                        for fmt in audio_formats:
                            mime = fmt.get('type', '')
                            if 'mp4' in mime or 'm4a' in mime:
                                best_audio = fmt
                                break
                        if not best_audio:
                            best_audio = audio_formats[0]
                        
                        stream_url = best_audio.get('url')
                        if stream_url:
                            return {
                                'success': True,
                                'data': {
                                    'url': stream_url,
                                    'title': data.get('title', ''),
                                    'duration': data.get('lengthSeconds', 0),
                                    'quality': best_audio.get('bitrate', 'unknown')
                                }
                            }
                except Exception as e:
                    # print(f"Invidious instance {instance} failed: {e}", file=sys.stderr)
                    continue
                    
            return None
        except Exception as e:
            # print(f"Invidious extraction failed: {e}", file=sys.stderr)
            return None

    def _get_stream_with_ytdlp_fast(self, video_id: str) -> Dict[str, Any]:
        """
        FAST yt-dlp extraction - optimized for speed over reliability
        """
        # Only try YouTube Music URL (faster)
        url = f"https://music.youtube.com/watch?v={video_id}"
        
        # Minimal yt-dlp options for speed
        fast_opts = {
            'quiet': True,
            'no_warnings': True,
            'extractaudio': False,
            'noplaylist': True,
            'no_check_certificate': True,
            'extract_flat': False,
            'format': 'bestaudio[ext=m4a]/bestaudio/best',  # Single format selector
            'extractor_args': {
                'youtube': {
                    'player_client': ['android'],  # Single fast client
                    'player_skip': ['webpage', 'configs'],
                }
            },
            'http_headers': {
                'User-Agent': 'com.google.android.youtube/17.36.4 (Linux; U; Android 12)'
            },
            'retries': 2,  # Reduced retries
            'socket_timeout': 10,  # Shorter timeout
        }

        try:
            if not HAS_YTDLP or YoutubeDL is None:
                raise Exception("yt-dlp is not available")

            # print(f"Fast yt-dlp extraction: {video_id}", file=sys.stderr)

            with YoutubeDL(fast_opts) as ydl:
                info = ydl.extract_info(url, download=False)

            stream_url = info.get('url')
            
            # Get audio URL from formats if not directly available
            if not stream_url:
                formats = info.get('formats', []) or []
                requested = info.get('requested_formats', []) or []
                all_formats = formats + requested
                
                audio_formats = [f for f in all_formats if f.get('acodec') and f.get('acodec') != 'none']
                if audio_formats:
                    # Pick best audio format
                    audio_formats.sort(key=lambda x: x.get('abr', 0) or 0, reverse=True)
                    stream_url = audio_formats[0].get('url')

            if not stream_url:
                raise Exception("No audio stream found")

            return {
                'success': True,
                'data': {
                    'url': stream_url,
                    'title': info.get('title', ''),
                    'duration': info.get('duration', 0),
                    'quality': str(info.get('abr', 'unknown'))
                }
            }

        except Exception as e:
            # print(f"Fast yt-dlp failed: {e}", file=sys.stderr)
            # Try regular yt-dlp as last resort
            return self._get_stream_with_ytdlp(video_id)

    def _get_stream_via_ytmusicapi(self, video_id: str) -> Optional[Dict[str, Any]]:
        """Attempt to retrieve a fast-start audio stream directly from ytmusicapi."""
        if not HAS_YTMUSICAPI or not self.yt:
            return None

        try:
            # print(f"🎵 ytmusicapi: Fetching song data for {video_id}", file=sys.stderr)
            song_data = self.yt.get_song(video_id)
            streaming_data = (song_data or {}).get('streamingData') or {}
            video_details = (song_data or {}).get('videoDetails') or {}

            adaptive_formats = streaming_data.get('adaptiveFormats') or []
            progressive_formats = streaming_data.get('formats') or []

            candidates: List[Dict[str, Any]] = []
            for fmt in adaptive_formats + progressive_formats:
                if not isinstance(fmt, dict):
                    continue
                # Handle both direct URL and signatureCipher
                url = fmt.get('url')
                if not url and fmt.get('signatureCipher'):
                    # Skip formats that require signature deciphering - yt-dlp handles these
                    continue
                mime_type = fmt.get('mimeType', '')
                if not url or 'audio' not in mime_type.lower():
                    continue
                candidates.append(fmt)

            if not candidates:
                # print(f"🎵 ytmusicapi: No direct audio URLs found for {video_id}", file=sys.stderr)
                return None

            def sort_key(fmt: Dict[str, Any]):
                bitrate = fmt.get('bitrate') or fmt.get('averageBitrate') or 0
                mime_type = fmt.get('mimeType', '')
                # Prefer m4a/mp4 for better compatibility
                ext_preference = 0 if 'audio/mp4' in mime_type or 'm4a' in mime_type else 1
                return (ext_preference, -bitrate)  # Lower ext_preference better, higher bitrate better

            selected = sorted(candidates, key=sort_key)[0]

            bitrate = selected.get('bitrate') or selected.get('averageBitrate')
            duration_raw = video_details.get('lengthSeconds')
            duration = float(duration_raw) if duration_raw else streaming_data.get('duration')

            # print(f"🎵 ytmusicapi: Found stream URL for {video_id}", file=sys.stderr)
            return {
                'success': True,
                'data': {
                    'url': selected.get('url'),
                    'title': video_details.get('title', ''),
                    'duration': duration or 0,
                    'quality': str(int(bitrate / 1000)) if bitrate else 'unknown'
                }
            }

        except Exception as err:
            # print(f"🎵 ytmusicapi failed for {video_id}: {err}", file=sys.stderr)
            logger.debug(f"ytmusicapi fast stream lookup failed for {video_id}: {err}")
            return None
    
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
        
        # Enhanced yt-dlp options for better compatibility with YouTube's recent changes
        enhanced_opts = {
            # Add specific options to handle YouTube's SABR streaming changes
            'quiet': True,
            'no_warnings': True,
            'extractaudio': False,
            'noplaylist': True,
            'no_check_certificate': True,
            'prefer_free_formats': True,
            'youtube_include_dash_manifest': True,  # Enable DASH to get more formats
            'extract_flat': False,
            # Critical: Use specific extractor args for YouTube
            'extractor_args': {
                'youtube': {
                    'player_client': ['android', 'web'],  # Use multiple clients
                    'player_skip': ['webpage'],  # Skip problematic checks
                }
            },
            # Updated user agent
            'http_headers': {
                'User-Agent': 'Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36'
            },
            # Retry settings
            'retries': 5,
            'fragment_retries': 5,
            'socket_timeout': 30,
        }

        # Try progressively more permissive format selectors before giving up entirely
        format_fallbacks = [
            'bestaudio[ext=m4a][abr<=160]/bestaudio[abr<=160]/bestaudio[ext=m4a]/bestaudio',
            'bestaudio[ext=m4a]/bestaudio',
            'bestaudio/best',
            'best'
        ]

        last_error = None

        for url in urls_to_try:
            if not HAS_YTDLP or YoutubeDL is None:
                raise Exception("yt-dlp is not available")

            for format_selector in format_fallbacks:
                opts = dict(enhanced_opts)
                opts['format'] = format_selector

                try:
                    print(
                        f"Trying to extract stream from: {url} with format '{format_selector}'",
                        file=sys.stderr
                    )

                    with YoutubeDL(opts) as ydl:
                        info = ydl.extract_info(url, download=False)

                    # Extract the best audio stream URL with improved format selection
                    stream_url = info.get('url')

                    raw_formats: List[Dict[str, Any]] = []
                    formats_field = info.get('formats')
                    if isinstance(formats_field, list):
                        raw_formats.extend([f for f in formats_field if isinstance(f, dict)])

                    requested_formats = info.get('requested_formats')
                    if isinstance(requested_formats, list):
                        raw_formats.extend([f for f in requested_formats if isinstance(f, dict)])

                    audio_formats = [
                        f for f in raw_formats
                        if (f.get('acodec') and f.get('acodec') != 'none') or f.get('audio_ext')
                    ]

                    if not stream_url and audio_formats:
                        # Improved format selection with better priority system
                        def format_priority(fmt):
                            abr = fmt.get('abr') or fmt.get('tbr') or 0
                            ext = fmt.get('ext', '')
                            acodec = fmt.get('acodec', '')

                            format_scores = {
                                'm4a': 100,
                                'mp4': 95,
                                'aac': 90,
                                'opus': 85,
                                'webm': 80
                            }

                            codec_scores = {
                                'mp4a': 100,
                                'aac': 95,
                                'opus': 90,
                                'vorbis': 80,
                            }

                            abr_penalty = -abs((abr or 0) - 160)
                            format_score = format_scores.get(ext, 70)
                            codec_score = codec_scores.get(acodec, 70)

                            return (format_score + codec_score, abr_penalty, abr)

                        best_format = max(audio_formats, key=format_priority)
                        stream_url = best_format.get('url')

                        print(
                            f"Selected format via manual pick: {best_format.get('format_id')} "
                            f"({best_format.get('ext')}, {best_format.get('acodec')}, abr={best_format.get('abr')})",
                            file=sys.stderr
                        )

                    if not stream_url and raw_formats:
                        for fmt in raw_formats:
                            if fmt.get('url') and (fmt.get('acodec') or fmt.get('audio_ext')):
                                stream_url = fmt.get('url')
                                print(
                                    f"Using fallback format: {fmt.get('format_id', 'unknown')}",
                                    file=sys.stderr
                                )
                                break

                    if not stream_url:
                        raise Exception("No valid stream URL found")

                    chosen_format = None
                    if audio_formats:
                        chosen_format = max(
                            audio_formats,
                            key=lambda f: (f.get('url') == stream_url, f.get('abr') or 0)
                        )

                    quality = None
                    if chosen_format:
                        quality = chosen_format.get('abr') or chosen_format.get('tbr')
                    if quality is None:
                        quality = info.get('abr')

                    quality_str = (
                        str(int(quality)) if isinstance(quality, (int, float)) else quality or 'unknown'
                    )

                    print(
                        f"Successfully extracted stream: quality={quality_str}, duration={info.get('duration', 0)}",
                        file=sys.stderr
                    )

                    return {
                        'success': True,
                        'data': {
                            'url': stream_url,
                            'title': info.get('title', ''),
                            'duration': info.get('duration', 0),
                            'quality': quality_str
                        }
                    }

                except Exception as format_error:
                    last_error = format_error
                    print(
                        f"Failed to extract from {url} with format '{format_selector}': {format_error}",
                        file=sys.stderr
                    )
                    # Try the next format selector for this URL
                    continue

            # If all format selectors failed for this URL, try the next URL variant
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
            
            # print(f"Generated watch playlist with {len(formatted_tracks)} tracks", file=sys.stderr)
            
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
    
    def get_lyrics(self, video_id: str, track_title: str = None, artist_name: str = None) -> Dict[str, Any]:
        """
        Get lyrics for a song.
        
        Priority:
        1. LRCLIB (fast HTTP GET, returns synced timestamps)
        2. YouTube Music plain lyrics (fallback)
        """
        try:
            # print(f"🎤 Lyrics request: title='{track_title}', artist='{artist_name}', videoId={video_id}", file=sys.stderr)
            
            # Step 1: Try LRCLIB for synced lyrics (fast, no auth needed)
            if track_title and artist_name:
                try:
                    lrclib_result = self._fetch_lrclib_lyrics(track_title, artist_name)
                    if lrclib_result:
                        # print(f"✅ Got lyrics from LRCLIB", file=sys.stderr)
                        return lrclib_result
                    else:
                        print(f"⚠️ LRCLIB returned no results", file=sys.stderr)
                except Exception as e:
                    print(f"⚠️ LRCLIB failed: {e}", file=sys.stderr)
            
            # Step 2: Fall back to YouTube Music plain lyrics
            if HAS_YTMUSICAPI and self.yt:
                try:
                    # print(f"🔄 Trying YTMusic lyrics for {video_id}...", file=sys.stderr)
                    watch_playlist = self.yt.get_watch_playlist(videoId=video_id)
                    lyrics_browse_id = watch_playlist.get('lyrics')
                    
                    if lyrics_browse_id:
                        # print(f"📝 Found lyrics browseId: {lyrics_browse_id}", file=sys.stderr)
                        lyrics_data = self.yt.get_lyrics(lyrics_browse_id)
                        if lyrics_data and lyrics_data.get('lyrics'):
                            # print(f"✅ Got plain lyrics from YTMusic", file=sys.stderr)
                            return {
                                'success': True,
                                'data': {
                                    'lyrics': lyrics_data.get('lyrics', ''),
                                    'source': lyrics_data.get('source', 'YouTube Music'),
                                    'syncedLyrics': None
                                }
                            }
                    else:
                        print(f"⚠️ No lyrics browseId in watch playlist", file=sys.stderr)
                except Exception as e:
                    print(f"⚠️ YTMusic lyrics failed: {e}", file=sys.stderr)
            
            print(f"❌ No lyrics found from any source", file=sys.stderr)
            return {
                'success': False,
                'error': 'No lyrics available for this song'
            }
            
        except Exception as e:
            logger.error(f"Failed to get lyrics: {e}")
            print(f"❌ Lyrics error: {e}", file=sys.stderr)
            return {
                'success': False,
                'error': str(e)
            }
    
    def _fetch_lrclib_lyrics(self, track: str, artist: str, album: str = None, duration: int = None) -> Optional[Dict[str, Any]]:
        """Synced lyrics from LRCLIB - module helper shared by all providers."""
        return fetch_lrclib_lyrics(track, artist, album=album, duration=duration)

    def _parse_lrc(self, lrc_text: str) -> list:
        """Parse LRC format into list of {time, text} objects."""
        import re
        lines = []
        pattern = re.compile(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)')
        
        for line in lrc_text.strip().split('\n'):
            match = pattern.match(line.strip())
            if match:
                minutes = int(match.group(1))
                seconds = int(match.group(2))
                centiseconds = match.group(3)
                # Handle both .xx and .xxx formats
                if len(centiseconds) == 2:
                    ms = int(centiseconds) * 10
                else:
                    ms = int(centiseconds)
                
                time_seconds = minutes * 60 + seconds + ms / 1000.0
                text = match.group(4).strip()
                
                lines.append({
                    'time': round(time_seconds, 3),
                    'text': text
                })
        
        return lines
    
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
            
            # print(f"Retrieved mood categories with {len(mood_data)} sections", file=sys.stderr)
            
            # Format the mood categories into the expected structure
            formatted_data = {}
            for section_name, categories in mood_data.items():
                formatted_categories = []
                for cat in categories:
                    if isinstance(cat, dict):
                        formatted_categories.append({
                            'title': cat.get('title', ''),
                            'params': cat.get('params', ''),
                            'thumbnailURL': ''  # YouTube Music doesn't provide thumbnails for categories
                        })
                formatted_data[section_name] = formatted_categories
            
            # print(f"🎭 Formatted {sum(len(v) for v in formatted_data.values())} mood categories", file=sys.stderr)
            
            return {
                'success': True,
                'data': formatted_data
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
            
            # print(f"Retrieved {len(playlists_data)} mood playlists", file=sys.stderr)
            
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
    
    def get_charts(self, country: str = 'IN') -> Dict[str, Any]:
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
            
            # print(f"Retrieved charts for country {country}", file=sys.stderr)
            
            # Format the charts data
            formatted_data = {
                'songs': [],
                'videos': [],
                'artists': [],
                'trending': []
            }
            
            # Format songs/tracks
            if 'songs' in charts_data:
                songs = charts_data['songs']
                items = songs.get('items', []) if isinstance(songs, dict) else songs
                for item in items[:20]:
                    formatted = self._format_single_result(item, 'songs')
                    if formatted:
                        formatted_data['songs'].append(formatted)
            
            # Format trending videos
            if 'videos' in charts_data:
                videos = charts_data['videos']
                items = videos.get('items', []) if isinstance(videos, dict) else videos
                for item in items[:15]:
                    formatted = self._format_single_result(item, 'songs')
                    if formatted:
                        formatted_data['videos'].append(formatted)
            
            # Format trending artists
            if 'artists' in charts_data:
                artists = charts_data['artists']
                items = artists.get('items', []) if isinstance(artists, dict) else artists
                for item in items[:15]:
                    formatted = self._format_single_result(item, 'artists')
                    if formatted:
                        formatted_data['artists'].append(formatted)
            
            # Format trending
            if 'trending' in charts_data:
                trending = charts_data['trending']
                items = trending.get('items', []) if isinstance(trending, dict) else trending
                for item in items[:15]:
                    formatted = self._format_single_result(item, 'songs')
                    if formatted:
                        formatted_data['trending'].append(formatted)
            
            # print(f"📊 Formatted charts: {len(formatted_data['songs'])} songs, {len(formatted_data['videos'])} videos", file=sys.stderr)
            
            return {
                'success': True,
                'data': formatted_data
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
            
            # print(f"Retrieved home feed with {len(home_data)} sections", file=sys.stderr)
            
            # Format the home data into sections with contents
            sections = []
            for section in home_data:
                if not isinstance(section, dict):
                    continue
                    
                title = section.get('title', '')
                contents_raw = section.get('contents', [])
                
                if not title or not contents_raw:
                    continue
                
                # Format each item in the section
                formatted_contents = []
                for item in contents_raw:
                    if not isinstance(item, dict):
                        continue
                    
                    # Determine the type based on available fields
                    if item.get('videoId'):
                        formatted_item = self._format_single_result(item, 'songs')
                    elif item.get('browseId') and 'album' in str(item.get('browseId', '')).lower():
                        formatted_item = self._format_single_result(item, 'albums')
                    elif item.get('playlistId'):
                        formatted_item = self._format_single_result(item, 'playlists')
                    elif item.get('browseId'):
                        # Could be artist or playlist
                        if 'artist' in title.lower() or item.get('subscribers'):
                            formatted_item = self._format_single_result(item, 'artists')
                        else:
                            formatted_item = self._format_single_result(item, 'playlists')
                    else:
                        formatted_item = self._format_single_result(item, 'songs')
                    
                    if formatted_item:
                        formatted_contents.append(formatted_item)
                
                if formatted_contents:
                    sections.append({
                        'title': title,
                        'contents': formatted_contents
                    })
            
            # print(f"🏠 Formatted {len(sections)} home sections for YouTube Music", file=sys.stderr)
            
            return {
                'success': True,
                'data': sections
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
        # print(f"🎵 Python received musicSource: '{music_source}'", file=sys.stderr)
        
        if music_source == 'jiosaavn':
            # print("🔥 Using JioSaavn service", file=sys.stderr)
            service = JioSaavnService()
        elif music_source == 'tidal':
            # print("🔥 Using Tidal service (Hi-Res Lossless)", file=sys.stderr)
            service = TidalService(
                preferred_quality=request_data.get('tidalQuality'),
                dolby_atmos=bool(request_data.get('tidalDolbyAtmos', False)),
                custom_api_url=request_data.get('tidalApiUrl'),
                api_key=request_data.get('tidalApiKey'),
            )
        else:
            # print("🔥 Using YouTube Music service", file=sys.stderr)
            service = YTMusicService()
            
        action = request_data.get('action')
        # print(f"🎵 Action: {action}", file=sys.stderr)
        
        if action == 'search':
            query = request_data.get('query', '')
            limit = request_data.get('limit', 20)
            return service.search_all(query, limit)
            
        elif action == 'stream':
            video_id = request_data.get('videoId', '')
            return service.get_stream_info(video_id)
        
        elif action == 'download_stream':
            video_id = request_data.get('videoId', '')
            # Use download-specific method for Tidal (Hi-Res first)
            if isinstance(service, TidalService):
                return service.get_stream_info_for_download(video_id)
            else:
                # Other sources use regular stream info
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
        
        elif action == 'load_more_songs':
            # Only Tidal supports this currently
            if isinstance(service, TidalService):
                query = request_data.get('query', '')
                offset = request_data.get('offset', 0)
                limit = request_data.get('limit', 20)
                return service.load_more_songs(query, offset, limit)
            else:
                return {
                    'success': False,
                    'error': 'Load more songs not supported for this music source'
                }
        
        elif action == 'artist_songs_paginated':
            # Paginated artist songs (Tidal only currently)
            browse_id = request_data.get('browseId', '')
            offset = request_data.get('offset', 0)
            limit = request_data.get('limit', 20)
            if isinstance(service, TidalService):
                return service.get_artist_songs_paginated(browse_id, offset, limit)
            else:
                # Other services don't support pagination, just return regular artist songs
                return service.get_artist_songs(browse_id)

        elif action == 'ai_search':
            query = request_data.get('query', '')
            limit = request_data.get('limit', 20)
            api_key = request_data.get('aiApiKey')
            if isinstance(service, YTMusicService):
                return service.ai_search(query, limit, gemini_api_key=api_key)
            else:
                # Fallback for services without AI enrichment
                base_response = service.search_all(query, limit)
                if not base_response.get('success'):
                    return base_response
                base_data = base_response.get('data', {}) or {}
                songs = base_data.get('songs', []) or []
                curated = songs[: min(len(songs), 6)]
                return {
                    'success': True,
                    'data': {
                        'query': query,
                        'suggestions': [],
                        'topResults': curated,
                        'results': base_data,
                        'insights': []
                    }
                }
            
        elif action == 'lyrics':
            video_id = request_data.get('videoId', '')
            track_title = request_data.get('trackTitle')
            artist_name = request_data.get('artistName')
            return service.get_lyrics(video_id, track_title=track_title, artist_name=artist_name)
            
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
                # print(f"Received request: {line}", file=sys.stderr, flush=True)
                
                request_data = json.loads(line)
                response = handle_request(request_data)
                
                # Log response to stderr for debugging
                # print(f"Sending response: {json.dumps(response)}", file=sys.stderr, flush=True)
                
                # Write response to stdout
                print(json.dumps(response), flush=True)
                
            except json.JSONDecodeError as e:
                error_response = {
                    'success': False,
                    'error': f'Invalid JSON: {str(e)}'
                }
                # print(f"JSON decode error: {e}", file=sys.stderr, flush=True)
                print(json.dumps(error_response), flush=True)
                
            except Exception as e:
                error_response = {
                    'success': False,
                    'error': str(e)
                }
                # print(f"Request error: {e}", file=sys.stderr, flush=True)
                print(json.dumps(error_response), flush=True)
                
    except KeyboardInterrupt:
        # print("Service interrupted", file=sys.stderr, flush=True)
        pass
    except Exception as e:
        pass
        # print(f"Main loop error: {e}", file=sys.stderr, flush=True)

if __name__ == '__main__':
    main()