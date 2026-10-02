//
//  UpdateManager.swift
//  Izzy
//
//  Created by Shubham Kumar on 06/09/25.
//

import Foundation
import AppKit

/// Manages automatic updates for the Izzy application
class UpdateManager: ObservableObject {
    /// Singleton instance
    static let shared = UpdateManager()
    
    /// Update status message
    @Published var updateStatus = "Checking for updates..."
    
    /// Whether an update is available
    @Published var isUpdateAvailable = false
    
    /// Latest version string
    @Published var latestVersion = ""
    
    /// Additional update message
    @Published var updateMessage = ""
    
    /// Whether an update check is in progress
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    
    // MARK: - Configuration
    /// GitHub repository owner
    private let repoOwner = "ShubhamPP04"
    
    /// GitHub repository name
    private let repoName = "Izzy"
    
    /// Update check URL for GitHub Releases
    private var updateCheckURL: String {
        return "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
    }
    
    /// Private initializer for singleton pattern
    private init() {}
    
    /// Check for available updates
    func checkForUpdates() {
        // Don't check if already checking
        guard !isChecking else { return }
        
        isChecking = true
        updateStatus = "Checking for updates..."
        updateMessage = ""
        
        // Get current app version
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        // Create URL for GitHub API request
        guard let url = URL(string: updateCheckURL) else {
            updateStatus = "Update check failed"
            updateMessage = "Invalid update URL. Please configure a valid GitHub repository."
            isChecking = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        // Add GitHub API accept header
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isChecking = false
                
                // Check for network connectivity issues
                if let error = error {
                    self.updateStatus = "Update check failed"
                    if error.localizedDescription.contains("Could not connect to the server") {
                        self.updateMessage = "Could not connect to GitHub. Please check your internet connection."
                    } else {
                        self.updateMessage = "Network error: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let data = data else {
                    self.updateStatus = "Update check failed"
                    self.updateMessage = "No data received from GitHub"
                    return
                }
                
                do {
                    // Parse the JSON response from GitHub API
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let tagName = json["tag_name"] as? String,
                       let htmlURL = json["html_url"] as? String {
                        
                        // Extract version number from tag (assuming format "v1.0.1" or "1.0.1")
                        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                        
                        // Compare versions
                        // Marketing-version comparison only: releases always
                        // bump the marketing version, and the releases API
                        // doesn't expose the build number.
                        if self.isNewerVersion(version, build: "0", than: currentVersion, build: "0") {
                            self.isUpdateAvailable = true
                            self.latestVersion = version
                            self.updateStatus = "Update available: v\(version)"
                            self.updateMessage = "New features and improvements are available for download."
                            
                            // Store download URL for later use
                            UserDefaults.standard.set(htmlURL, forKey: "UpdateDownloadURL")
                        } else {
                            self.isUpdateAvailable = false
                            self.updateStatus = "You're up to date (v\(currentVersion))"
                            self.updateMessage = "This is the latest version of Izzy."
                        }
                    } else {
                        self.updateStatus = "Update check failed"
                        self.updateMessage = "Invalid response format from GitHub API"
                    }
                } catch {
                    self.updateStatus = "Update check failed"
                    self.updateMessage = "Failed to parse update information: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Download the available update
    /// ⬇️ Kaset-style in-app update: download the release DMG with progress,
    /// mount it, replace the running bundle (with rollback on failure), and
    /// relaunch. No browser, no manual drag.
    func downloadUpdate() {
        guard !isDownloading, !latestVersion.isEmpty else { return }
        Task { await downloadAndInstall() }
    }
    
    private func downloadAndInstall() async {
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            updateMessage = ""
        }
        defer { Task { await MainActor.run { self.isDownloading = false } } }
        
        let dmgURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/download/v\(latestVersion)/Izzy.dmg")!
        
        // ---- 1. Download (streamed to disk, throttled progress) ----
        let tmpDMG = FileManager.default.temporaryDirectory
            .appendingPathComponent("Izzy-\(latestVersion).dmg")
        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: dmgURL)
            let expected = (response as? HTTPURLResponse)?.expectedContentLength ?? -1
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NSError(domain: "UpdateManager", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "Download failed (HTTP \(http.statusCode))"])
            }
            FileManager.default.createFile(atPath: tmpDMG.path, contents: nil)
            let handle = try FileHandle(forWritingTo: tmpDMG)
            defer { try? handle.close() }
            
            var received: Int64 = 0
            var lastReport = Date.distantPast
            for try await byte in bytes {
                handle.write(Data([byte]))
                received += 1
                let now = Date()
                if now.timeIntervalSince(lastReport) > 0.15 {
                    lastReport = now
                    let done = expected > 0 ? Double(received) / Double(expected) : 0
                    await MainActor.run {
                        downloadProgress = done
                        updateStatus = expected > 0
                            ? String(format: "Downloading v%@… %.0f%%", latestVersion, done * 100)
                            : String(format: "Downloading v%@… %.1f MB", latestVersion, Double(received) / 1_048_576)
                    }
                }
            }
        } catch {
            await MainActor.run {
                updateStatus = "Download failed"
                updateMessage = error.localizedDescription
            }
            return
        }
        
        // ---- 2. Install ----
        do {
            try await installDMG(at: tmpDMG)
        } catch {
            await MainActor.run {
                updateStatus = "Install failed"
                updateMessage = error.localizedDescription
            }
            return
        }
    }
    
    private func installDMG(at dmgURL: URL) async throws {
        let fm = FileManager.default
        let mountPoint = fm.temporaryDirectory
            .appendingPathComponent("izzy-update-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        
        func run(_ path: String, _ args: [String]) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw NSError(domain: "UpdateManager", code: Int(process.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: "\(path) exited \(process.terminationStatus)"])
            }
        }
        
        await MainActor.run { updateStatus = "Installing…" }
        try run("/usr/bin/hdiutil", ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint.path])
        
        let mountedApp = mountPoint.appendingPathComponent("Izzy.app")
        guard fm.fileExists(atPath: mountedApp.path) else {
            try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
            throw NSError(domain: "UpdateManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Izzy.app not found in the downloaded DMG"])
        }
        
        // Replace the running bundle in place when it lives in /Applications;
        // otherwise install to /Applications.
        let currentPath = Bundle.main.bundlePath
        let destination = currentPath.hasPrefix("/Applications") ? currentPath : "/Applications/Izzy.app"
        let oldAside = (destination as NSString).deletingLastPathComponent
            + "/Izzy-old-\(UUID().uuidString)"
        
        if fm.fileExists(atPath: destination) {
            try fm.moveItem(atPath: destination, toPath: oldAside)
        }
        do {
            try run("/usr/bin/ditto", [mountedApp.path, destination])
        } catch {
            try? fm.moveItem(atPath: oldAside, toPath: destination)  // rollback
            try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
            throw NSError(domain: "UpdateManager", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not write to \(destParent(destination)). Install manually from the GitHub releases page."])
        }
        try? fm.removeItem(atPath: oldAside)
        try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
        
        // ---- 3. Relaunch into the new version ----
        await MainActor.run { updateStatus = "Relaunching…" }
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 0.7 && open '\(destination)'"]
        try? relaunch.run()
        NSApp.terminate(nil)
    }
    
    private func destParent(_ path: String) -> String {
        (path as NSString).deletingLastPathComponent
    }
    
    /// Check for updates automatically (called periodically)
    func autoCheckForUpdates() {
        // Only check if auto-update is enabled
        let autoUpdateEnabled = UserDefaults.standard.bool(forKey: "AutoUpdateEnabled")
        if autoUpdateEnabled {
            checkForUpdates()
        }
    }
    
    // MARK: - Private Methods
    
    /// Compare two versions to determine if the new version is newer than the old version
    /// - Parameters:
    ///   - newVersion: The new version string to compare
    ///   - build: The new build number
    ///   - oldVersion: The old version string to compare against
    ///   - build: The old build number
    /// - Returns: True if the new version is newer than the old version
    private func isNewerVersion(_ newVersion: String, build newBuild: String, than oldVersion: String, build oldBuild: String) -> Bool {
        // Simple version comparison
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let oldComponents = oldVersion.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(newComponents.count, oldComponents.count) {
            let newNum = i < newComponents.count ? newComponents[i] : 0
            let oldNum = i < oldComponents.count ? oldComponents[i] : 0
            
            if newNum > oldNum {
                return true
            } else if newNum < oldNum {
                return false
            }
        }
        
        // If versions are equal, compare build numbers
        if let newBuildNum = Int(newBuild), let oldBuildNum = Int(oldBuild) {
            return newBuildNum > oldBuildNum
        }
        
        return false
    }
}