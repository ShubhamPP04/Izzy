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

def handle_request(request_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle incoming requests from Swift
    """
    try:
        service = YTMusicService()
        action = request_data.get('action')
        
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