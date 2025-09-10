# Installing Izzy

Thank you for downloading Izzy! Follow these simple steps to install the app:

## Installation Instructions

1. **Drag Izzy to Applications**
   - Drag the Izzy.app icon to the Applications folder shown in this window

2. **Eject the DMG**
   - Drag the DMG icon to the Trash or right-click and select "Eject"

3. **Remove Quarantine Attribute**
   - Open Terminal and run this command:
   ```
   xattr -rd com.apple.quarantine "/Applications/Izzy.app"
   ```

4. **Launch Izzy**
   - Open Izzy from your Applications folder or use Spotlight search
   - Grant accessibility permissions when prompted

5. **Start Using**
   - Press `Option + Space` from anywhere in macOS to show/hide Izzy
   - Start typing to search for music!

## Security Note

macOS adds a "quarantine" attribute to downloaded applications as a security measure. The command in step 3 removes this attribute, which is necessary for Izzy to run properly on your system.

This is a standard procedure for apps downloaded from the internet and does not compromise your system security.

## Need Help?

If you encounter any issues:
- Visit our [GitHub Issues](https://github.com/your-username/izzy/issues) page
- Check the full documentation in the [README](https://github.com/your-username/izzy/blob/main/README.md)

Enjoy using Izzy!