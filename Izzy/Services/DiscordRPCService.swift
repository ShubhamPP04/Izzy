//
//  DiscordRPCService.swift
//  Izzy
//
//  Discord Rich Presence over Discord's local IPC socket (/tmp/discord-ipc-N).
//  No SDK: frames are an 8-byte little-endian header (u32 op, u32 length) plus
//  a JSON payload. Everything fails silent — if Discord isn't running we simply
//  stay disconnected and retry on the next track change.
//
//  Note: external image URLs are not whitelisted for the client id, so no
//  artwork is sent — text presence only.
//

import Combine
import Foundation

final class DiscordRPCService: ObservableObject {
    static let shared = DiscordRPCService()
    /// Replace with your own Discord application id if you want Izzy's name
    /// shown on your profile instead of the shared one.
    static let defaultClientID = "1026584560296693760"

    @Published private(set) var isConnected = false

    private var socket: FileHandle?
    private var heartbeat: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()
    private let ioQueue = DispatchQueue(label: "izzy.discord-rpc", qos: .utility)
    private var currentTrack: Track?

    private init() {
        NotificationCenter.default.publisher(for: .izzyTrackChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let track = note.userInfo?["track"] as? Track else { return }
                self?.currentTrack = track
                self?.updatePresenceIfEnabled()
            }
            .store(in: &cancellables)

        PlaybackManager.shared.$playbackState
            .receive(on: DispatchQueue.main)
            .removeDuplicates { $0.isPlaying == $1.isPlaying }
            .sink { [weak self] state in
                guard let self else { return }
                if state.isPlaying {
                    self.updatePresenceIfEnabled()
                } else if self.isConnected {
                    // Pause clears the presence; playback restores it.
                    self.clearPresence()
                }
            }
            .store(in: &cancellables)
    }

    private func updatePresenceIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "discordRichPresenceEnabled"),
              let track = currentTrack else { return }
        ioQueue.async { [weak self] in
            self?.sendActivity(for: track)
        }
    }

    // MARK: - Activity payloads

    private func activityPayload(for track: Track, playing: Bool) -> [String: Any] {
        var activity: [String: Any] = [
            "details": String(track.title.prefix(128)),
            "state": "by \(String(track.artist.prefix(120)))",
        ]
        if track.duration > 0, playing {
            activity["timestamps"] = [
                "start": Int(Date().timeIntervalSince1970),
                "end": Int(Date().timeIntervalSince1970 + track.duration),
            ]
        }
        activity["assets"] = ["large_text": String(track.artist.prefix(120))]
        var args: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "activity": activity,
        ]
        if !playing {
            args["activity"] = ["details": String(track.title.prefix(128)),
                                "state": "paused"]
        }
        return [
            "cmd": "SET_ACTIVITY",
            "args": args,
            "nonce": UUID().uuidString,
        ]
    }

    private func clearPayload() -> [String: Any] {
        [
            "cmd": "SET_ACTIVITY",
            "args": ["pid": ProcessInfo.processInfo.processIdentifier,
                     "activity": NSNull()],
            "nonce": UUID().uuidString,
        ]
    }

    private func sendActivity(for track: Track) {
        guard ensureConnected() else { return }
        let playing = PlaybackManager.shared.playbackState.isPlaying
        write(payload: activityPayload(for: track, playing: playing))
    }

    private func clearPresence() {
        ioQueue.async { [weak self] in
            guard let self, self.socket != nil else { return }
            self.write(payload: self.clearPayload())
        }
    }

    // MARK: - Socket plumbing

    private func socketURL() -> URL? {
        for i in 0...9 {
            let path = "/tmp/discord-ipc-\(i)"
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    private func ensureConnected() -> Bool {
        if socket != nil { return true }
        guard let url = socketURL() else {
            isConnected = false
            return false
        }
        let fd = open(url.path, O_RDWR)
        guard fd >= 0 else {
            isConnected = false
            return false
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        socket = handle
        guard handshake(handle: handle) else {
            disconnect()
            return false
        }
        isConnected = true
        startHeartbeat()
        return true
    }

    private func handshake(handle: FileHandle) -> Bool {
        let payload: [String: Any] = [
            "v": 1,
            "client_id": Self.defaultClientID,
            "nonce": UUID().uuidString,
        ]
        write(op: 0, payload: payload, to: handle)
        guard let (op, _) = readFrame(handle: handle), op == 0 else { return false }
        return true
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: ioQueue)
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [weak self] in
            guard let self, let handle = self.socket else { return }
            self.write(op: 3, payload: ["_": UUID().uuidString], to: handle)
            // Treat a dead read side as disconnect; Discord closes on exit.
            if let (op, _) = self.readFrame(handle: handle), op == 11 { return } // pong-ish
        }
        timer.resume()
        heartbeat = timer
    }

    private func write(payload: [String: Any]) {
        guard let handle = socket else { return }
        write(op: 1, payload: payload, to: handle)
    }

    private func write(op: UInt32, payload: [String: Any], to handle: FileHandle) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var header = Data(count: 8)
        header.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            let p = raw.bindMemory(to: UInt32.self)
            p[0] = op.littleEndian
            p[1] = UInt32(data.count).littleEndian
        }
        handle.write(header)
        handle.write(data)
    }

    private func readFrame(handle: FileHandle) -> (UInt32, Data)? {
        guard let header = try? handle.read(upToCount: 8), header.count == 8 else { return nil }
        let op = header.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        let length = header.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).littleEndian }
        guard length > 0, let body = try? handle.read(upToCount: Int(length)), body.count == Int(length) else {
            return (op, Data())
        }
        return (op, body)
    }

    private func disconnect() {
        heartbeat?.cancel()
        heartbeat = nil
        try? socket?.close()
        socket = nil
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
        }
    }
}
