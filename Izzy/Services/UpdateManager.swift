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
                        if self.isNewerVersion(version, build: "1", than: currentVersion, build: buildNumber) {
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
    func downloadUpdate() {
        updateStatus = "Opening download page..."
        updateMessage = "Redirecting to download page..."
        
        // Get download URL from UserDefaults
        guard let downloadURLString = UserDefaults.standard.string(forKey: "UpdateDownloadURL"),
              let url = URL(string: downloadURLString) else {
            updateStatus = "Download failed"
            updateMessage = "Invalid download URL"
            return
        }
        
        // Open the download URL in the browser
        NSWorkspace.shared.open(url)
        
        // Update status to indicate the user has been redirected
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateStatus = "Redirected to download page"
            self.updateMessage = "Please download the latest version from the GitHub release page."
        }
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