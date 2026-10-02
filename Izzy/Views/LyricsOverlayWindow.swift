//
//  LyricsOverlayWindow.swift
//  Izzy
//
//  Created by Shubham Kumar on 01/10/26.
//

import SwiftUI
import AppKit

// MARK: - Desktop Lyrics Overlay Controller

/// 🖥️ Manages the floating desktop-lyrics overlay panel: a non-activating
/// NSPanel pinned bottom-center that shows the current synced lyric line.
/// The panel is created lazily and fully released when hidden.
@MainActor
final class LyricsOverlayController: ObservableObject {
    static let shared = LyricsOverlayController()

    /// Whether the overlay is currently on screen (toggles reflect this).
    @Published private(set) var isVisible: Bool = false

    /// 🎤 Lyrics for the currently displayed track (nil = nothing fetched yet).
    @Published private(set) var lyrics: LyricsData?

    /// VideoId whose lyrics are cached — avoids refetching on every tick.
    private var cachedVideoId: String?

    private var panel: NSPanel?
    /// 🔍 UI scale for the overlay (fonts + panel size), persisted.
    @Published var scale: Double {
        didSet {
            guard scale != oldValue else { return }
            UserDefaults.standard.set(scale, forKey: "lyricsOverlayScale")
        }
    }

    private init() {
        let saved = UserDefaults.standard.double(forKey: "lyricsOverlayScale")
        scale = min(max(saved > 0 ? saved : 1.0, 0.6), 2.2)
    }

    // MARK: Visibility

    /// 🎛️ Show/hide the overlay. Idempotent; hiding closes AND releases the
    /// panel (the next show builds a fresh one with cached lyrics).
    func setVisible(_ visible: Bool) {
        if visible {
            if panel == nil { makePanel() }
            panel?.orderFrontRegardless()
            isVisible = true
            fetchLyricsIfNeeded()
        } else {
            panel?.orderOut(nil)
            panel = nil
            isVisible = false
        }
    }

    // MARK: Panel Construction

    /// 🏗️ Build the borderless, non-activating overlay panel.
    private func makePanel() {
        let size = currentSize()
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        // 📍 Default: bottom-center of the main screen, a little above the dock.
        let origin = NSPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.minY + 24
        )

        let overlayPanel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlayPanel.level = .floating
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayPanel.hidesOnDeactivate = false
        overlayPanel.isOpaque = false
        overlayPanel.backgroundColor = .clear
        overlayPanel.hasShadow = false
        overlayPanel.isReleasedWhenClosed = false
        overlayPanel.ignoresMouseEvents = false
        overlayPanel.becomesKeyOnlyIfNeeded = true

        // 🖱️ AppKit mouse-event dragging (see OverlayHostingView) — smoothest
        // possible: native event rate, no SwiftUI gesture coalescing.
        overlayPanel.isMovableByWindowBackground = false
        overlayPanel.contentView = OverlayHostingView(rootView: LyricsOverlayView(controller: self))
        restoreFrame(into: overlayPanel)
        panel = overlayPanel
    }

    // MARK: Sizing & Persistence

    /// Base size the scale multiplies.
    static let baseSize = NSSize(width: 600, height: 140)

    func currentSize() -> NSSize {
        NSSize(width: Self.baseSize.width * scale, height: Self.baseSize.height * scale)
    }

    /// 🔍 Live resize from the grip; keeps the top-left corner pinned so the
    /// text stays anchored where the user is looking.
    func applyScale(_ newScale: Double) {
        let clamped = min(max(newScale, 0.6), 2.2)
        guard let panel, abs(clamped - scale) > 0.001 else { return }
        let oldFrame = panel.frame
        let newSize = NSSize(width: Self.baseSize.width * clamped,
                             height: Self.baseSize.height * clamped)
        let newFrame = NSRect(x: oldFrame.minX,
                              y: oldFrame.maxY - newSize.height,
                              width: newSize.width,
                              height: newSize.height)
        scale = clamped
        panel.setFrame(newFrame, display: true)
        persistFrame()
        objectWillChange.send()
    }

    func persistFrame() {
        guard let panel else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "lyricsOverlayFrame")
    }

    /// Restores the saved frame (position + size) clamped on-screen.
    private func restoreFrame(into target: NSPanel) {
        guard let saved = UserDefaults.standard.string(forKey: "lyricsOverlayFrame") else { return }
        var frame = NSRectFromString(saved)
        if let visible = NSScreen.main?.visibleFrame {
            frame.size.width = min(frame.width, visible.width)
            frame.size.height = min(frame.height, visible.height)
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        }
        target.setFrame(frame, display: false)
    }

    // MARK: Lyrics Fetching

    /// 🎤 Fetch lyrics when the displayed track changes; the last videoId is
    /// cached so repeated calls are free. Fails soft to `.unavailable`.
    func fetchLyricsIfNeeded() {
        guard let track = PlaybackManager.shared.currentTrack else {
            cachedVideoId = nil
            lyrics = nil
            return
        }
        guard track.videoId != cachedVideoId else { return }
        cachedVideoId = track.videoId

        let videoId = track.videoId
        let title = track.title
        let artist = track.artist

        Task { [weak self] in
            do {
                let fetched = try await PythonServiceManager.shared.getLyrics(
                    videoId: videoId,
                    title: title,
                    artist: artist
                )
                await MainActor.run {
                    guard let self = self, self.cachedVideoId == videoId else { return }
                    self.lyrics = fetched
                }
            } catch {
                print("❌ Overlay lyrics failed: \(error.localizedDescription)")
                await MainActor.run {
                    guard let self = self, self.cachedVideoId == videoId else { return }
                    self.lyrics = .unavailable
                }
            }
        }
    }
}

// MARK: - Overlay Content View

/// SwiftUI content of the desktop-lyrics panel: the current synced line in
/// large text over a glassy background, with plain-lyrics and title/artist
/// fallbacks when no synced lyrics exist.
struct LyricsOverlayView: View {
    @ObservedObject var controller: LyricsOverlayController
    @ObservedObject private var playbackManager = PlaybackManager.shared

    // ⏸️ Frozen line index while paused — lets the timeline skip recompute work.
    @State private var frozenLineIndex: Int?
    // 🔍 Scale when the current resize gesture began.
    @State private var dragStartScale: Double?

    var body: some View {
        // ⏱️ ~20fps while playing (interpolated clock → line changes land on
        // time), 1fps when paused (nothing moves).
        TimelineView(.periodic(from: .now, by: playbackManager.playbackState.isPlaying ? 0.05 : 0.5)) { _ in
            overlayContent
        }
        .onChange(of: playbackManager.currentTrack?.videoId) { _, _ in
            frozenLineIndex = nil
            controller.fetchLyricsIfNeeded()
        }
        .onChange(of: playbackManager.playbackState) { _, newState in
            // ⏸️ Freeze the current line when playback stops/pauses; thaw on play.
            switch newState {
            case .playing:
                frozenLineIndex = nil
            case .paused:
                frozenLineIndex = syncedLineIndex()
            default:
                frozenLineIndex = nil
            }
        }
        .onAppear {
            controller.fetchLyricsIfNeeded()
        }
    }

    // MARK: Chrome

    private var overlayContent: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay {
                overlayText
                    .padding(.horizontal, 20 * controller.scale)
                    .padding(.vertical, 12 * controller.scale)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .overlay(alignment: .bottomTrailing) {
                resizeGrip
            }
    }

    /// 🔍 Bottom-right grip: drag to resize (fonts + panel scale together).
    private var resizeGrip: some View {
        Image(systemName: "arrow.down.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.5))
            .padding(6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragStartScale == nil { dragStartScale = controller.scale }
                        controller.applyScale((dragStartScale ?? 1.0) + value.translation.width / 300)
                    }
                    .onEnded { _ in dragStartScale = nil }
            )
            .help("Drag to resize")
    }

    // MARK: Text

    @ViewBuilder
    private var overlayText: some View {
        if let track = playbackManager.currentTrack {
            VStack(alignment: .leading, spacing: 6) {
                // 🏷️ Slim header: what's playing
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)

                    Text(track.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(track.artist)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }

                mainLineView(for: track)
            }
        } else {
            // 💤 Nothing playing — fail soft with a quiet placeholder.
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("Nothing playing")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func mainLineView(for track: Track) -> some View {
        if let lyrics = controller.lyrics, lyrics.isSynced, let lines = lyrics.syncedLyrics {
            // 🎤 Current synced line, large, with a peek at the next line.
            let index = displayLineIndex(for: lines)
            VStack(alignment: .leading, spacing: 3) {
                Text(lines[index].text.isEmpty ? " " : lines[index].text)
                    .font(.system(size: 18 * controller.scale, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.3), value: index)

                if index + 1 < lines.count, !lines[index + 1].text.isEmpty {
                    Text(lines[index + 1].text)
                        .font(.system(size: 13 * controller.scale, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let lyrics = controller.lyrics, lyrics.isAvailable {
            // 📝 No synced lines — show the first plain lines instead.
            let plainLines = lyrics.lines
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .prefix(2)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(plainLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            // 🤷 No lyrics at all — fall back to title / artist.
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // MARK: Line Index

    /// Last line whose timestamp <= currentTime (skipped entirely while paused).
    private func displayLineIndex(for lines: [SyncedLine]) -> Int {
        if let frozen = frozenLineIndex {
            return min(max(frozen, 0), lines.count - 1)
        }
        return syncedLineIndex()
    }

    private func syncedLineIndex() -> Int {
        guard let lines = controller.lyrics?.syncedLyrics, !lines.isEmpty else { return 0 }
        let time = playbackManager.interpolatedTime()
        var index = 0
        for (i, line) in lines.enumerated() where line.time <= time {
            index = i
        }
        return index
    }
}

/// Hosting view that drags the borderless overlay with raw AppKit mouse
/// events — full event-rate tracking, no gesture coalescing, no fighting
/// between AppKit window-move logic and a SwiftUI DragGesture (the old
/// approach stuttered).
final class OverlayHostingView: NSHostingView<LyricsOverlayView> {
    private var dragStartOrigin: NSPoint?
    private var dragStartMouse: NSPoint?

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragStartOrigin = window?.frame.origin
        dragStartMouse = NSEvent.mouseLocation
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let origin = dragStartOrigin, let startMouse = dragStartMouse else {
            super.mouseDragged(with: event)
            return
        }
        let now = NSEvent.mouseLocation
        var x = origin.x + (now.x - startMouse.x)
        var y = origin.y + (now.y - startMouse.y)
        if let visible = window.screen?.visibleFrame {
            x = min(max(x, visible.minX), visible.maxX - window.frame.width)
            y = min(max(y, visible.minY), visible.maxY - window.frame.height)
        }
        window.setFrameOrigin(NSPoint(x: x, y: y))
        rootView.controller.persistFrame()
    }

    override func mouseUp(with event: NSEvent) {
        dragStartOrigin = nil
        dragStartMouse = nil
        super.mouseUp(with: event)
    }
}
