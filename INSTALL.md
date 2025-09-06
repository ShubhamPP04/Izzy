# Izzy - Complete Installation & Build Guide

This comprehensive guide will walk you through every step of installing, building, and distributing the Izzy music player app for macOS.

## 📋 Table of Contents

1. [System Requirements](#-system-requirements)
2. [Quick Installation (End Users)](#-quick-installation-end-users)
3. [Developer Setup](#-developer-setup)
4. [Building from Source](#-building-from-source)
5. [Creating Distribution DMG](#-creating-distribution-dmg)
6. [Troubleshooting](#-troubleshooting)
7. [Advanced Configuration](#-advanced-configuration)

## 🖥️ System Requirements

### Minimum Requirements
- **Operating System**: macOS 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel
- **Internet Connection**: Required for music streaming

### For Development
- **Xcode**: 16.0 or later
- **Command Line Tools**: Latest version
- **Python**: 3.8 or later (for music service backend)
- **Git**: For version control

## 🚀 Quick Installation (End Users)

### Method 1: DMG Installation (Recommended)

1. **Download the DMG**
   ```bash
   # Download from GitHub releases (replace with actual URL)
   curl -L -o Izzy.dmg "https://github.com/your-username/izzy/releases/latest/download/Izzy.dmg"
   ```

2. **Mount and Install**
   ```bash
   # Mount the DMG
   open Izzy.dmg
   
   # Drag Izzy to Applications folder
   # (This can be done through Finder GUI)
   ```

3. **First Launch**
   ```bash
   # Launch from Applications
   open /Applications/Izzy.app
   
   # Or use Spotlight
   # Press Cmd+Space, type "Izzy", press Enter
   ```

4. **Grant Permissions**
   - When prompted, grant **Accessibility** permissions in System Settings
   - Go to: System Settings > Privacy & Security > Accessibility
   - Add Izzy to the list and enable it

5. **Start Using**
   - Press `Option + Space` from anywhere in macOS
   - Start typing to search for music
   - Click any result to play

### Method 2: Direct App Installation

If you have the built `.app` file:

```bash
# Copy to Applications
cp -R Izzy.app /Applications/

# Make executable
chmod +x /Applications/Izzy.app/Contents/MacOS/Izzy

# Launch
open /Applications/Izzy.app
```

## 👨‍💻 Developer Setup

### Step 1: Install Development Tools

1. **Install Xcode**
   ```bash
   # Install from Mac App Store or download from developer portal
   # Verify installation
   xcode-select --install
   xcrun xcodebuild -version
   ```

2. **Install Python and Dependencies**
   ```bash
   # Check Python version
   python3 --version  # Should be 3.8+
   
   # Install required Python packages
   pip3 install ytmusicapi yt-dlp requests
   
   # Verify installation
   python3 -c "import ytmusicapi; print('ytmusicapi installed successfully')"
   ```

3. **Install Additional Tools** (Optional)
   ```bash
   # Install Homebrew if not already installed
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Install useful development tools
   brew install git python3 node
   ```

### Step 2: Clone and Setup Project

```bash
# Clone the repository
git clone https://github.com/your-username/izzy.git
cd izzy

# Verify project structure
ls -la
# Should see: Izzy.xcodeproj, Izzy/, build_dmg.sh, README.md, etc.

# Make build script executable
chmod +x build_dmg.sh
```

### Step 3: Configure Xcode Project

1. **Open in Xcode**
   ```bash
   open Izzy.xcodeproj
   ```

2. **Configure Code Signing**
   - Select the Izzy target in Xcode
   - Go to "Signing & Capabilities" tab
   - Select your development team
   - Ensure "Automatically manage signing" is checked
   - Update bundle identifier if needed (e.g., `com.yourname.Izzy`)

3. **Verify Build Settings**
   - Deployment Target: macOS 15.5
   - Architecture: arm64, x86_64 (Universal)
   - Swift Language Version: Swift 5

## 🔨 Building from Source

### Debug Build (Development)

```bash
# Method 1: Using Xcode
# Open Izzy.xcodeproj and press Cmd+R

# Method 2: Command Line
cd /path/to/izzy
xcodebuild -project Izzy.xcodeproj \
           -scheme Izzy \
           -configuration Debug \
           -destination 'platform=macOS' \
           build

# Built app location:
# ~/Library/Developer/Xcode/DerivedData/Izzy-*/Build/Products/Debug/Izzy.app
```

### Release Build

```bash
# Build release version
xcodebuild -project Izzy.xcodeproj \
           -scheme Izzy \
           -configuration Release \
           -destination 'platform=macOS' \
           build

# Or use the automated script
./build_dmg.sh
```

### Build Script Breakdown

The `build_dmg.sh` script performs these steps:

```bash
#!/bin/bash
set -e

# 1. Clean previous builds
rm -rf build dist
mkdir -p dist

# 2. Build and archive
xcodebuild -project Izzy.xcodeproj \
           -scheme Izzy \
           -configuration Release \
           -archivePath build/Izzy.xcarchive \
           archive

# 3. Export app
xcodebuild -exportArchive \
           -archivePath build/Izzy.xcarchive \
           -exportPath build/Release \
           -exportOptionsPlist ExportOptions.plist

# 4. Create DMG
hdiutil create -volname "Izzy" \
               -srcfolder build/Release \
               -ov -format UDZO \
               dist/Izzy.dmg
```

## 📦 Creating Distribution DMG

### Automated DMG Creation

```bash
# Use the provided script
./build_dmg.sh

# This will create dist/Izzy.dmg (~896KB)
```

### Manual DMG Creation

```bash
# Step 1: Build the app
xcodebuild -project Izzy.xcodeproj \
           -scheme Izzy \
           -configuration Release \
           -archivePath build/Izzy.xcarchive \
           archive

# Step 2: Export
xcodebuild -exportArchive \
           -archivePath build/Izzy.xcarchive \
           -exportPath build/Release \
           -exportOptionsPlist ExportOptions.plist

# Step 3: Create temp DMG directory
mkdir -p dmg_temp
cp -R build/Release/Izzy.app dmg_temp/
ln -s /Applications dmg_temp/Applications

# Step 4: Create DMG
hdiutil create -volname "Izzy Music Player" \
               -srcfolder dmg_temp \
               -ov -format UDZO \
               Izzy.dmg

# Step 5: Clean up
rm -rf dmg_temp
```

### Custom DMG with Background Image

```bash
# Create a more professional DMG
mkdir dmg_source
cp -R Izzy.app dmg_source/
ln -s /Applications dmg_source/Applications

# Add background image (optional)
mkdir dmg_source/.background
cp background.png dmg_source/.background/

# Create DMG with custom properties
hdiutil create -volname "Izzy Music Player v1.0" \
               -srcfolder dmg_source \
               -format UDZO \
               -imagekey zlib-level=9 \
               IzzyInstaller.dmg
```

## 🔧 Troubleshooting

### Common Build Issues

#### Issue: "No such file or directory" for Python dependencies
```bash
# Solution: Install Python dependencies
pip3 install ytmusicapi yt-dlp

# Or specify Python path in build settings
export PYTHONPATH="/usr/local/lib/python3.11/site-packages"
```

#### Issue: Code signing errors
```bash
# Solution 1: Check signing identity
security find-identity -v -p codesigning

# Solution 2: Reset signing
# In Xcode: Target > Signing & Capabilities > Reset to Suggested Settings
```

#### Issue: "App can't be opened" on other Macs
```bash
# Solution: Properly sign and notarize the app
codesign --deep --force --verify --verbose \
         --sign "Developer ID Application: Your Name (TEAM_ID)" \
         Izzy.app

# Then notarize with Apple
xcrun notarytool submit Izzy.dmg \
                       --keychain-profile "notarytool-password" \
                       --wait
```

### Runtime Issues

#### Issue: Global hotkey not working
```bash
# Check accessibility permissions
# System Settings > Privacy & Security > Accessibility
# Ensure Izzy is listed and enabled

# Test from terminal
open -a Izzy
# Then test Option+Space
```

#### Issue: No music playback
```bash
# Check Python backend
python3 ytmusic_service.py --test

# Check audio permissions
# System Settings > Privacy & Security > Microphone (if using microphone)
# System Settings > Privacy & Security > Media & Apple Music
```

#### Issue: App crashes on launch
```bash
# Check console logs
log show --predicate 'subsystem == "com.yourname.Izzy"' --last 1h

# Or use Console.app to monitor logs
open -a Console
```

### Performance Issues

```bash
# Check app memory usage
ps aux | grep Izzy

# Monitor CPU usage
top -pid $(pgrep Izzy)

# Check for memory leaks (in Xcode)
# Product > Profile > Leaks
```

## ⚙️ Advanced Configuration

### Build Configuration

- **Development Language**: Swift 5.9+
- **UI Framework**: SwiftUI 5.0+
- **Deployment Target**: macOS 14.0
- **Xcode Version**: 15.0 or later

### Build Configurations

Edit `Izzy.xcodeproj/project.pbxproj` or use Xcode:

```swift
// Debug configuration
SWIFT_OPTIMIZATION_LEVEL = "-Onone"
DEBUG_INFORMATION_FORMAT = "dwarf"
ENABLE_TESTABILITY = YES

// Release configuration  
SWIFT_OPTIMIZATION_LEVEL = "-O"
DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"
ENABLE_TESTABILITY = NO
```

### Custom Export Options

Edit `ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
```

### Environment Variables

```bash
# Set build environment variables
export PRODUCT_NAME="Izzy"
export BUNDLE_IDENTIFIER="com.yourname.izzy"
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Python environment
export PYTHONPATH="/usr/local/lib/python3.11/site-packages"
export PYTHON_EXECUTABLE="/usr/bin/python3"
```

### Custom Build Scripts

Create `scripts/build.sh`:

```bash
#!/bin/bash
set -e

echo "🚀 Building Izzy Music Player..."

# Clean
xcodebuild clean -project Izzy.xcodeproj -scheme Izzy

# Build
xcodebuild build \
    -project Izzy.xcodeproj \
    -scheme Izzy \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64'

# Test (optional)
xcodebuild test \
    -project Izzy.xcodeproj \
    -scheme Izzy \
    -destination 'platform=macOS'

echo "✅ Build completed successfully!"
```

### Continuous Integration

Example GitHub Actions workflow (`.github/workflows/build.yml`):

```yaml
name: Build and Release

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        run: |
          pip3 install ytmusicapi yt-dlp
          
      - name: Build App
        run: |
          xcodebuild -project Izzy.xcodeproj \
                     -scheme Izzy \
                     -configuration Release \
                     archive \
                     -archivePath build/Izzy.xcarchive
          
      - name: Create DMG
        run: ./build_dmg.sh
        
      - name: Upload DMG
        uses: actions/upload-artifact@v3
        with:
          name: Izzy-DMG
          path: dist/Izzy.dmg
```

## 📝 Final Notes

### Distribution Checklist

Before distributing your app:

- [ ] Test on multiple macOS versions
- [ ] Verify code signing
- [ ] Check all dependencies are included
- [ ] Test installation from DMG
- [ ] Verify accessibility permissions work
- [ ] Test global hotkey functionality
- [ ] Check music playback on different systems
- [ ] Validate app icon and metadata
- [ ] Create release notes
- [ ] Upload to GitHub releases

### Security Considerations

- Always sign your app with a valid Apple Developer ID
- Consider notarizing for distribution outside the App Store  
- Keep dependencies updated for security patches
- Test on clean systems to ensure no missing dependencies

### Performance Tips

- Use Release builds for distribution
- Enable compiler optimizations
- Strip debug symbols for smaller binary size
- Test memory usage with realistic workloads
- Profile app startup time

---

This completes the comprehensive installation and build guide for Izzy. Follow these steps carefully for successful building and distribution of the app.
