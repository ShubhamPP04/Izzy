# Izzy - Installation Guide

This guide provides detailed instructions for installing and running Izzy on macOS, including important security considerations.

## 📋 Table of Contents

1. [System Requirements](#-system-requirements)
2. [Installation Steps](#-installation-steps)
3. [Security Considerations](#-security-considerations)
4. [First Launch](#-first-launch)
5. [Troubleshooting](#-troubleshooting)

## 🖥️ System Requirements

### Minimum Requirements
- **Operating System**: macOS 14.0 (Sonoma) or later
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel
- **Internet Connection**: Required for music streaming

## 🚀 Installation Steps

### Step 1: Download the DMG
1. Visit the [Releases page](../../releases) on GitHub
2. Download the latest `Izzy.dmg` file
3. Wait for the download to complete

### Step 2: Mount the DMG
1. Locate the downloaded `Izzy.dmg` file (usually in your Downloads folder)
2. Double-click the DMG file to mount it
3. A new window should appear showing the Izzy app and a shortcut to Applications

### Step 3: Install Izzy
1. Drag the `Izzy.app` icon to the Applications folder
2. Wait for the copy process to complete
3. You can now eject the DMG by dragging it to the Trash or right-clicking and selecting "Eject"

### Step 4: Remove Quarantine Attribute (Important)
After installing Izzy to your Applications folder, you need to remove the quarantine attribute to avoid Gatekeeper warnings:

Open Terminal and run:
```bash
xattr -rd com.apple.quarantine "/Applications/Izzy.app"
```

This command removes the quarantine attribute and allows macOS to run the app normally. You only need to do this once after installation.

## 🔒 Security Considerations

### Understanding the Quarantine Attribute
When you download applications from the internet, macOS automatically applies a "quarantine" attribute as a security measure. This attribute:
- Triggers Gatekeeper warnings when you first try to open the app
- Helps protect your system from potentially malicious software
- Is automatically applied to all downloaded files

### Why You Need to Remove It
While Izzy is safe and properly built, the quarantine attribute will cause macOS to display a warning when you first launch it. Removing the attribute tells macOS that you trust this application.

### The Removal Command Explained
```bash
xattr -rd com.apple.quarantine "/Applications/Izzy.app"
```
- `xattr`: Command to work with extended attributes
- `-r`: Remove the attribute recursively (from all files in the app bundle)
- `-d`: Delete the specified attribute
- `com.apple.quarantine`: The specific attribute to remove
- `"/Applications/Izzy.app"`: Path to the application

## 🎯 First Launch

### Granting Accessibility Permissions
1. Launch Izzy by double-clicking it in your Applications folder or searching for it with Spotlight
2. macOS will prompt you to grant accessibility permissions
3. Go to System Settings > Privacy & Security > Accessibility
4. Find Izzy in the list and enable the checkbox next to it
5. You may need to unlock the settings by clicking the lock icon in the bottom left

### Using the Global Hotkey
Once permissions are granted, you can use the global hotkey to show/hide Izzy from anywhere:
- Press `Option + Space` to toggle the Izzy window

## 🔧 Troubleshooting

### Issue: "App can't be opened" Error
**Solution**: Remove the quarantine attribute:
```bash
xattr -rd com.apple.quarantine "/Applications/Izzy.app"
```

### Issue: Global Hotkey Not Working
**Solution**: Check accessibility permissions:
1. Go to System Settings > Privacy & Security > Accessibility
2. Ensure Izzy is listed and enabled
3. If not present, add it by clicking the "+" button and selecting Izzy from Applications

### Issue: Music Not Playing
**Solution**: Check internet connection and Python dependencies:
1. Ensure you have an active internet connection
2. Verify that Python 3.8+ is installed on your system
3. Install required Python packages:
   ```bash
   pip3 install ytmusicapi yt-dlp requests
   ```

### Issue: App Crashes on Launch
**Solution**: Check system compatibility:
1. Verify you're running macOS 14.0 or later
2. Check that your system meets the minimum requirements
3. Try reinstalling the app

## 🔄 Updating Izzy

Izzy includes an automatic update system:
1. The app automatically checks for updates every 24 hours
2. You can manually check for updates in the Settings panel (⌘ + ,)
3. When an update is available, you'll receive a notification
4. Follow the prompts to download and install the update

---

<div align="center">

Made with ❤️ for the macOS community

**[Download Latest Release](../../releases/latest)** • **[View Documentation](../../wiki)** • **[Report Issues](../../issues)**

</div>