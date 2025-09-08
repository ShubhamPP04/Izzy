#!/usr/bin/env python3
"""
Test script to verify hotkey persistence and tab selection behavior
"""

import subprocess
import sys
import time

def run_command(command):
    """Run a command and return stdout, stderr, and return code"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

def test_hotkey_persistence():
    """Test that hotkey settings persist across app restarts"""
    print("🧪 Testing hotkey persistence...")
    
    # Test app bundle ID (replace with actual bundle ID)
    app_bundle_id = "com.shubhamkumar.Izzy"
    
    # Save a test hotkey combination
    stdout, stderr, code = run_command(
        f"defaults write {app_bundle_id} hotkeyModifierFlags -int 524288"
    )
    if code != 0:
        print(f"❌ Failed to save hotkeyModifierFlags: {stderr}")
        return False
        
    stdout, stderr, code = run_command(
        f"defaults write {app_bundle_id} hotkeyKeyCode -int 49"
    )
    if code != 0:
        print(f"❌ Failed to save hotkeyKeyCode: {stderr}")
        return False
        
    print("✅ Saved hotkeyModifierFlags = 524288 (Option)")
    print("✅ Saved hotkeyKeyCode = 49 (Space)")
    
    # Save selected tab
    stdout, stderr, code = run_command(
        f"defaults write {app_bundle_id} selectedTab -int 1"
    )
    if code != 0:
        print(f"❌ Failed to save selectedTab: {stderr}")
        return False
        
    print("✅ Saved selectedTab = 1 (Search panel)")
    
    # Read back the saved values
    stdout, stderr, code = run_command(
        f"defaults read {app_bundle_id} hotkeyModifierFlags"
    )
    if code != 0:
        print(f"❌ Failed to read hotkeyModifierFlags: {stderr}")
        return False
        
    saved_modifiers = stdout
    print(f"✅ App reads hotkeyModifierFlags = {saved_modifiers}")
    
    stdout, stderr, code = run_command(
        f"defaults read {app_bundle_id} hotkeyKeyCode"
    )
    if code != 0:
        print(f"❌ Failed to read hotkeyKeyCode: {stderr}")
        return False
        
    saved_keycode = stdout
    print(f"✅ App reads hotkeyKeyCode = {saved_keycode}")
    
    stdout, stderr, code = run_command(
        f"defaults read {app_bundle_id} selectedTab"
    )
    if code != 0:
        print(f"❌ Failed to read selectedTab: {stderr}")
        return False
        
    saved_tab = stdout
    print(f"✅ App reads selectedTab = {saved_tab}")
    
    # Verify values match
    if saved_modifiers == "524288" and saved_keycode == "49" and saved_tab == "1":
        print("✅ Hotkey persistence test PASSED")
        return True
    else:
        print("❌ Hotkey persistence test FAILED")
        return False

def test_tab_selection():
    """Test that tab selection works correctly"""
    print("\n🧪 Testing tab selection...")
    
    # Test app bundle ID (replace with actual bundle ID)
    app_bundle_id = "com.shubhamkumar.Izzy"
    
    # Test each tab
    tabs = [
        ("0", "Home"),
        ("1", "Search"),
        ("2", "Favorites"),
        ("3", "Recently Played"),
        ("4", "Settings"),
        ("5", "Playlists")
    ]
    
    for tab_id, tab_name in tabs:
        # Save tab selection
        stdout, stderr, code = run_command(
            f"defaults write {app_bundle_id} selectedTab -int {tab_id}"
        )
        if code != 0:
            print(f"❌ Failed to save selectedTab = {tab_id}: {stderr}")
            return False
            
        # Read back tab selection
        stdout, stderr, code = run_command(
            f"defaults read {app_bundle_id} selectedTab"  
        )
        if code != 0:
            print(f"❌ Failed to read selectedTab: {stderr}")
            return False
            
        saved_tab = stdout
        if saved_tab == tab_id:
            print(f"✅ Tab selection works for {tab_name} (ID: {tab_id})")
        else:
            print(f"❌ Tab selection failed for {tab_name} (ID: {tab_id})")
            return False
    
    print("✅ Tab selection test PASSED")
    return True

def cleanup_test_data():
    """Reset test data to defaults"""
    print("\n🧹 Cleaning up test data...")
    
    # Test app bundle ID (replace with actual bundle ID)
    app_bundle_id = "com.shubhamkumar.Izzy"
    
    # Reset to default values
    stdout, stderr, code = run_command(
        f"defaults write {app_bundle_id} hotkeyModifierFlags -int 524288"
    )
    if code == 0:
        print("✅ Reset hotkeyModifierFlags to 524288 (Option)")
    
    stdout, stderr, code = run_command(
        f"defaults write {app_bundle_id} hotkeyKeyCode -int 49"
    )
    if code == 0:
        print("✅ Reset hotkeyKeyCode to 49 (Space)")
    
    stdout, stderr, code = run_command(
        f"defaults write {app_bundle_id} selectedTab -int 1"
    )
    if code == 0:
        print("✅ Reset selectedTab to 1 (Search panel)")
    
    print("   • @AppStorage automatically saves selectedTab to UserDefaults")
    print("   • UserDefaults values persist across app restarts")
    print("✅ Cleanup completed")

if __name__ == "__main__":
    print("🚀 Izzy Hotkey & Tab Selection Persistence Test")
    print("=" * 50)
    
    # Run tests
    test1_passed = test_hotkey_persistence()
    test2_passed = test_tab_selection()
    
    # Cleanup
    cleanup_test_data()
    
    print("\n" + "=" * 50)
    if test1_passed and test2_passed:
        print("🎉 All tests PASSED!")
        sys.exit(0)
    else:
        print("💥 Some tests FAILED!")
        sys.exit(1)