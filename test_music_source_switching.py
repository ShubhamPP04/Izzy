#!/usr/bin/env python3

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'Izzy'))

import json
from ytmusic_service import handle_request

def test_music_source_switching():
    """Test that music source switching works correctly"""
    
    print("🧪 Testing Music Source Switching...")
    print("=" * 60)
    
    # Test 1: YouTube Music search
    print("\n1. Testing YouTube Music Search:")
    print("-" * 40)
    
    youtube_request = {
        "action": "search",
        "query": "test song",
        "limit": 3,
        "musicSource": "youtube_music"
    }
    
    try:
        youtube_result = handle_request(youtube_request)
        if youtube_result.get('success', False):
            data = youtube_result.get('data', {})
            songs = data.get('songs', [])
            print(f"✅ YouTube Music returned {len(songs)} songs")
            if songs:
                first_song = songs[0]
                print(f"   📱 First song: '{first_song.get('title', 'N/A')}' by '{first_song.get('artist', 'N/A')}'")
                print(f"   🔗 Video ID: {first_song.get('videoId', 'N/A')}")
        else:
            print(f"❌ YouTube Music search failed: {youtube_result.get('error', 'Unknown error')}")
    except Exception as e:
        print(f"❌ YouTube Music search error: {e}")
    
    # Test 2: JioSaavn search  
    print("\n2. Testing JioSaavn Search:")
    print("-" * 40)
    
    jiosaavn_request = {
        "action": "search",
        "query": "bollywood song",
        "limit": 3,
        "musicSource": "jiosaavn"
    }
    
    try:
        jiosaavn_result = handle_request(jiosaavn_request)
        if jiosaavn_result.get('success', False):
            data = jiosaavn_result.get('data', {})
            songs = data.get('songs', [])
            print(f"✅ JioSaavn returned {len(songs)} songs")
            if songs:
                first_song = songs[0]
                print(f"   📱 First song: '{first_song.get('title', 'N/A')}' by '{first_song.get('artist', 'N/A')}'")
                print(f"   🆔 Song ID: {first_song.get('id', 'N/A')}")
        else:
            print(f"❌ JioSaavn search failed: {jiosaavn_result.get('error', 'Unknown error')}")
    except Exception as e:
        print(f"❌ JioSaavn search error: {e}")
    
    # Test 3: Default behavior (should fallback to YouTube Music)
    print("\n3. Testing Default Behavior (no musicSource specified):")
    print("-" * 40)
    
    default_request = {
        "action": "search",
        "query": "popular song",
        "limit": 2
    }
    
    try:
        default_result = handle_request(default_request)
        if default_result.get('success', False):
            data = default_result.get('data', {})
            songs = data.get('songs', [])
            print(f"✅ Default service returned {len(songs)} songs")
            if songs:
                first_song = songs[0]
                print(f"   📱 First song: '{first_song.get('title', 'N/A')}' by '{first_song.get('artist', 'N/A')}'")
                # Check if it has YouTube-specific fields
                if first_song.get('videoId'):
                    print("   🔥 Detected YouTube Music service (has videoId)")
                elif first_song.get('id') and not first_song.get('videoId'):
                    print("   🔥 Detected JioSaavn service (has id but no videoId)")
        else:
            print(f"❌ Default search failed: {default_result.get('error', 'Unknown error')}")
    except Exception as e:
        print(f"❌ Default search error: {e}")
    
    print("\n" + "=" * 60)
    print("✅ Music source switching test completed!")

if __name__ == "__main__":
    test_music_source_switching()
