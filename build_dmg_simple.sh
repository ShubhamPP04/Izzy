#!/bin/bash

# Simplified build script for Izzy app DMG creation (without code signing)
set -e

# Configuration
APP_NAME="Izzy"
DMG_NAME="Izzy"
BUILD_DIR="build"
DIST_DIR="dist"
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

echo "🚀 Building $APP_NAME..."

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build the app directly (without archiving)
echo "📦 Building app with xcodebuild..."
xcodebuild -project Izzy.xcodeproj \
           -scheme Izzy \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           BUILD_LIBRARY_FOR_DISTRIBUTION=NO \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGN_ENTITLEMENTS="" \
           clean build

# Update the Info.plist to the correct version
APP_VERSION="1.1.8"
APP_BUILD="17"
echo "📝 Updating app version to ${APP_VERSION}..."
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_PATH/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$APP_BUILD" "$APP_PATH/Contents/Info.plist"

# Verify the version update
echo "🔍 Verifying version update..."
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist")
BUILD_VERSION=$(plutil -extract CFBundleVersion raw "$APP_PATH/Contents/Info.plist")
echo "✅ App version: $VERSION ($BUILD_VERSION)"

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