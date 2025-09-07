#!/usr/bin/env python3

import sys
import os
# Add the Izzy folder to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'Izzy'))

try:
    from ytmusic_service import decode_html_entities
    print("✅ Successfully imported decode_html_entities")
except ImportError as e:
    print(f"❌ Failed to import decode_html_entities: {e}")
    sys.exit(1)

def test_html_decoding():
    """Test HTML entity decoding function"""
    
    # Test cases with common HTML entities
    test_cases = [
        ("Song &amp; Dance", "Song & Dance"),
        ("Artist &quot;Name&quot;", "Artist \"Name\""),
        ("Title &amp; &quot;Subtitle&quot;", "Title & \"Subtitle\""),
        ("Normal Title", "Normal Title"),
        ("&lt;Less Than&gt;", "<Less Than>"),
        ("&apos;Apostrophe&apos;", "'Apostrophe'"),
        ("Multiple &amp; &amp; entities", "Multiple & & entities"),
    ]
    
    print("Testing HTML entity decoding...")
    print("-" * 50)
    
    all_passed = True
    for input_text, expected in test_cases:
        result = decode_html_entities(input_text)
        passed = result == expected
        all_passed = all_passed and passed
        
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} | Input: '{input_text}' -> Output: '{result}'")
        if not passed:
            print(f"      Expected: '{expected}'")
        print()
    
    print("-" * 50)
    if all_passed:
        print("🎉 All tests passed! HTML entity decoding is working correctly.")
    else:
        print("⚠️  Some tests failed. Check the implementation.")
    
    return all_passed

if __name__ == "__main__":
    test_html_decoding()
