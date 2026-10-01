//
//  LastFMService.swift
//  Izzy
//
//  Last.fm scrobbling via Web Services 2.0. Users supply their own API key +
//  shared secret (last.fm/api); the mobile session endpoint exchanges
//  username/password for a session key that lives in the Keychain, never in
//  UserDefaults. Now-playing is sent on track change; a scrobble fires once a
//  track has been listened to for ≥50% of its length or ≥240s.
//

import Combine
import CryptoKit
import Foundation
import Security

final class LastFMService: ObservableObject {
    static let shared = LastFMService()

    static let apiBase = "https://ws.audioscrobbler.com/2.0/"

    @Published var isAuthenticated = false
    @Published var isConnecting = false
    @Published var lastError: String?

    private var cancellables = Set<AnyCancellable>()
    private var currentTrack: Track?
    private var accumulated: Double = 0
    private var lastTick: Double?
    private var scrobbledForID: String?
    private var nowPlayedForID: String?

    private var sessionKey: String? {
        get { Self.keychainRead(account: username) }
        set {
            if let newValue {
                Self.keychainWrite(newValue, account: username)
            } else {
                Self.keychainDelete(account: username)
            }
        }
    }

    private var username: String {
        UserDefaults.standard.string(forKey: "lastfmUsername") ?? ""
    }

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "lastfmScrobblingEnabled")
    }

    private init() {
        NotificationCenter.default.publisher(for: .izzyTrackChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let track = note.userInfo?["track"] as? Track else { return }
                self?.handleTrackChanged(track)
            }
            .store(in: &cancellables)

        PlaybackManager.shared.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.accumulate(time: time)
            }
            .store(in: &cancellables)
    }

    // MARK: - Auth

    @discardableResult
    func authenticate() async -> Bool {
        let apiKey = UserDefaults.standard.string(forKey: "lastfmApiKey")?.trimmingCharacters(in: .whitespaces) ?? ""
        let secret = UserDefaults.standard.string(forKey: "lastfmSecret")?.trimmingCharacters(in: .whitespaces) ?? ""
        let user = username
        let password = UserDefaults.standard.string(forKey: "lastfmPassword") ?? ""

        guard !apiKey.isEmpty, !secret.isEmpty, !user.isEmpty, !password.isEmpty else {
            await MainActor.run { self.lastError = "Fill in API key, secret, username and password" }
            return false
        }

        await MainActor.run { self.isConnecting = true; self.lastError = nil }
        defer { Task { await MainActor.run { self.isConnecting = false } } }

        // Signature: alphabetically ordered "keyvalue" concat + secret, md5.
        let params = ["api_key": apiKey, "method": "auth.getMobileSession",
                      "password": password, "username": user]
        let sig = Self.signature(params: params, secret: secret)

        var components = URLComponents(string: Self.apiBase)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) } + [
            URLQueryItem(name: "api_sig", value: sig),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            await MainActor.run { self.lastError = "Could not reach Last.fm" }
            return false
        }
        if let session = json["session"] as? [String: Any],
           let key = session["key"] as? String {
            sessionKey = key
            await MainActor.run {
                self.isAuthenticated = true
                self.lastError = nil
            }
            return true
        }
        let message = (json["message"] as? String) ?? "Authentication failed"
        await MainActor.run { self.lastError = message }
        return false
    }

    func signOut() {
        sessionKey = nil
        isAuthenticated = false
    }

    /// Last.fm signature: params sorted alphabetically as key+value, secret appended.
    private static func signature(params: [String: String], secret: String) -> String {
        let concat = params.sorted { $0.key < $1.key }
            .map { "\($0.key)\($0.value)" }
            .joined() + secret
        let digest = Insecure.MD5.hash(data: Data(concat.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Scrobbling

    private func handleTrackChanged(_ track: Track) {
        // Count the finished track if it earned a scrobble.
        scrobbleIfEarned()
        currentTrack = track
        accumulated = 0
        lastTick = nil
        scrobbledForID = nil

        guard isEnabled, isAuthenticated,
              let sk = sessionKey,
              !track.title.isEmpty,
              track.title != nowPlayedForID else { return }
        nowPlayedForID = track.title
        let apiKey = UserDefaults.standard.string(forKey: "lastfmApiKey") ?? ""
        let secret = UserDefaults.standard.string(forKey: "lastfmSecret") ?? ""
        var params = ["api_key": apiKey, "artist": track.artist,
                      "method": "track.updateNowPlaying", "sk": sk,
                      "track": track.title]
        if track.duration > 0 {
            params["duration"] = String(Int(track.duration))
        }
        params["api_sig"] = Self.signature(params: params, secret: secret)
        post(params: params)
    }

    private func accumulate(time: Double) {
        guard playbackManager.isPlaying, currentTrack != nil else { lastTick = nil; return }
        defer { lastTick = time }
        guard let last = lastTick else { lastTick = time; return }
        let delta = time - last
        guard delta > 0, delta <= 2.0 else { return } // seek guard
        accumulated += delta
        scrobbleIfEarned()
    }

    private func scrobbleIfEarned() {
        guard isEnabled, isAuthenticated, let sk = sessionKey,
              let track = currentTrack,
              scrobbledForID != track.videoId,
              !track.title.isEmpty else { return }
        let duration = track.duration
        let earned = (duration > 0 && accumulated >= duration / 2) || accumulated >= 240
        guard earned else { return }
        scrobbledForID = track.videoId

        let apiKey = UserDefaults.standard.string(forKey: "lastfmApiKey") ?? ""
        let secret = UserDefaults.standard.string(forKey: "lastfmSecret") ?? ""
        var params = ["api_key": apiKey, "artist": track.artist,
                      "method": "track.scrobble", "sk": sk,
                      "timestamp": String(Int(Date().timeIntervalSince1970)),
                      "track": track.title]
        if duration > 0 {
            params["duration"] = String(Int(duration))
        }
        params["api_sig"] = Self.signature(params: params, secret: secret)
        post(params: params)
    }

    /// POST (Last.fm requires POST for write endpoints), failures swallowed.
    private func post(params: [String: String]) {
        var request = URLRequest(url: URL(string: Self.apiBase)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = params.map { "\($0.key)=\(Self.urlEncode($0.value))" }.joined(separator: "&")
        request.httpBody = body.data(using: .utf8)
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error { print("⚠️ Last.fm request failed: \(error.localizedDescription)") }
        }.resume()
    }

    private var playbackManager: PlaybackManager { PlaybackManager.shared }

    private static func urlEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    // MARK: - Keychain

    private static func keychainWrite(_ secret: String, account: String) {
        let data = Data(secret.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Izzy LastFM",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func keychainRead(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Izzy LastFM",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainDelete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Izzy LastFM",
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
