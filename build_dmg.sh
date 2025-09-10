#!/bin/bash

# Build script for Izzy app DMG creation
set -e

# Configuration
APP_NAME="Izzy"
DMG_NAME="Izzy"
BUILD_DIR="build"
DIST_DIR="dist"
APP_PATH="$BUILD_DIR/Release/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

echo "🚀 Building $APP_NAME..."

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build the app using xcodebuild
echo "📦 Building app with xcodebuild..."
xcodebuild -project Izzy.xcodeproj \
           -scheme Izzy \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
           archive

# Export the app
echo "📤 Exporting app..."
xcodebuild -exportArchive \
           -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
           -exportPath "$BUILD_DIR/Release" \
           -exportOptionsPlist ExportOptions.plist

# Check if app was built successfully
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App build failed - $APP_PATH not found"
    exit 1
fi

echo "✅ App built successfully at $APP_PATH"

# Bundle Python backend into app Resources
echo "📦 Bundling Python backend..."
RESOURCES_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES_DIR"

# Copy Python service script (use the Xcode project version)
if [ -f "Izzy/ytmusic_service.py" ]; then
  cp "Izzy/ytmusic_service.py" "$RESOURCES_DIR/"
  echo "✅ Copied ytmusic_service.py from Xcode project"
elif [ -f "ytmusic_service.py" ]; then
  cp "ytmusic_service.py" "$RESOURCES_DIR/"
  echo "✅ Copied ytmusic_service.py from root (fallback)"
else
  echo "⚠️ ytmusic_service.py not found in Xcode project or repo root; skipping copy"
fi

# Copy update files
echo "📦 Bundling update files..."
if [ -f "update.json" ]; then
  cp "update.json" "$RESOURCES_DIR/"
  echo "✅ Copied update.json"
fi

if [ -f "appcast.xml" ]; then
  cp "appcast.xml" "$RESOURCES_DIR/"
  echo "✅ Copied appcast.xml"
fi

if [ -f "release-notes.html" ]; then
  cp "release-notes.html" "$RESOURCES_DIR/"
  echo "✅ Copied release-notes.html"
fi

# Copy virtual environment or runtime if present
if [ -d "music_env" ]; then
  rsync -a --delete --exclude "**/__pycache__" --exclude "**/*.pyc" "music_env" "$RESOURCES_DIR/"
  echo "✅ Copied music_env to Resources"
elif [ -d "build/python_runtime" ]; then
  rsync -a --delete "build/python_runtime" "$RESOURCES_DIR/"
  echo "✅ Copied python_runtime to Resources"
else
  echo "⚠️ No bundled Python env found (music_env or build/python_runtime). App will fall back to system Python."
fi

# Re-sign the app if signing identity is available
CODESIGN_IDENTITY=${CODESIGN_IDENTITY:-}
if [ -n "$CODESIGN_IDENTITY" ]; then
  echo "🔏 Re-signing app with identity: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH" || { echo "❌ Code sign verify failed"; exit 1; }
else
  echo "ℹ️ Skipping code signing (CODESIGN_IDENTITY not set)"
fi

# Create DMG
echo "💿 Creating DMG..."

# Create a temporary directory for DMG contents
DMG_TEMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Copy DMG README if it exists
if [ -f "DMG_README.md" ]; then
  cp "DMG_README.md" "$DMG_TEMP_DIR/README.md"
  echo "📄 Copied DMG README"
fi

# Create the DMG
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$DMG_TEMP_DIR" \
               -ov \
               -format UDZO \
               "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP_DIR"

echo "✅ DMG created successfully at $DMG_PATH"

# Show file size
echo "📊 DMG size: $(du -h "$DMG_PATH" | cut -f1)"

echo "🎉 Build complete!"