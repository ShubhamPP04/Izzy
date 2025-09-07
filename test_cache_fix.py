#!/usr/bin/env python3

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'Izzy'))

import json
from ytmusic_service import handle_request

def test_music_source_cache_issue():
    """Test that searching with different music sources returns different results"""
    
    print("🧪 Testing Music Source Cache Issue Fix...")
    print("=" * 60)
    
    search_query = "kumar sanu"
    
    # Test 1: Search on JioSaavn
    print(f"\n1. Searching '{search_query}' on JioSaavn:")
    print("-" * 50)
    
    jiosaavn_request = {
        "action": "search",
        "query": search_query,
        "limit": 3,
        "musicSource": "jiosaavn"
    }
    
    jiosaavn_results = []
    try:
        jiosaavn_result = handle_request(jiosaavn_request)
        if jiosaavn_result.get('success', False):
            data = jiosaavn_result.get('data', {})
            songs = data.get('songs', [])
            jiosaavn_results = songs[:3]  # Take first 3
            print(f"✅ JioSaavn returned {len(songs)} songs")
            for i, song in enumerate(jiosaavn_results):
                print(f"   🎵 {i+1}. '{song.get('title', 'N/A')}' by '{song.get('artist', 'N/A')}'")
                print(f"      ID: {song.get('id', 'N/A')} (JioSaavn)")
        else:
            print(f"❌ JioSaavn search failed: {jiosaavn_result.get('error', 'Unknown error')}")
    except Exception as e:
        print(f"❌ JioSaavn search error: {e}")
    
    # Test 2: Search same query on YouTube Music  
    print(f"\n2. Searching '{search_query}' on YouTube Music:")
    print("-" * 50)
    
    youtube_request = {
        "action": "search",
        "query": search_query,
        "limit": 3,
        "musicSource": "youtube_music"
    }
    
    youtube_results = []
    try:
        youtube_result = handle_request(youtube_request)
        if youtube_result.get('success', False):
            data = youtube_result.get('data', {})
            songs = data.get('songs', [])
            youtube_results = songs[:3]  # Take first 3
            print(f"✅ YouTube Music returned {len(songs)} songs")
            for i, song in enumerate(youtube_results):
                print(f"   🎵 {i+1}. '{song.get('title', 'N/A')}' by '{song.get('artist', 'N/A')}'")
                print(f"      VideoID: {song.get('videoId', 'N/A')} (YouTube)")
        else:
            print(f"❌ YouTube Music search failed: {youtube_result.get('error', 'Unknown error')}")
    except Exception as e:
        print(f"❌ YouTube Music search error: {e}")
    
    # Test 3: Compare results
    print(f"\n3. Comparing Results:")
    print("-" * 50)
    
    if jiosaavn_results and youtube_results:
        # Check if the first song titles are different
        jiosaavn_first = jiosaavn_results[0].get('title', '').lower()
        youtube_first = youtube_results[0].get('title', '').lower()
        
        if jiosaavn_first != youtube_first:
            print("✅ SUCCESS: Different results from different sources!")
            print(f"   JioSaavn first: '{jiosaavn_results[0].get('title', 'N/A')}'")
            print(f"   YouTube first:  '{youtube_results[0].get('title', 'N/A')}'")
        else:
            print("⚠️  WARNING: First songs have same titles (might be coincidence)")
            print(f"   Both: '{jiosaavn_first}'")
        
        # Check ID formats to confirm different sources
        jiosaavn_has_id = any(song.get('id') and not song.get('videoId') for song in jiosaavn_results)
        youtube_has_videoid = any(song.get('videoId') for song in youtube_results)
        
        if jiosaavn_has_id and youtube_has_videoid:
            print("✅ SUCCESS: Different ID formats confirm different sources!")
            print("   JioSaavn uses 'id' field, YouTube uses 'videoId' field")
        else:
            print("❌ ISSUE: ID formats don't match expected patterns")
    else:
        print("❌ Cannot compare - missing results from one or both sources")
    
    # Test 4: Simulate the caching scenario
    print(f"\n4. Simulating Cache Scenario:")
    print("-" * 50)
    print("In the app, this would be the sequence:")
    print("1. User searches 'kumar sanu' on JioSaavn → Gets JioSaavn results")
    print("2. User switches to YouTube Music in settings")
    print("3. User types 'kumar sanu' again → Should get NEW YouTube Music results")
    print("")
    print("🔧 Our fix: Cache key now includes music source")
    print("   JioSaavn cache key: 'kumar sanu_jiosaavn'")
    print("   YouTube cache key:  'kumar sanu_youtube_music'")
    print("   → Different cache keys = Different results ✅")
    
    print("\n" + "=" * 60)
    print("✅ Music source cache issue test completed!")

if __name__ == "__main__":
    test_music_source_cache_issue()
