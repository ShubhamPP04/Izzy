//
//  AISearchViewModel.swift
//  Izzy
//
//  Replaced Gemini-based AI search with Apple Intelligence (Foundation Models).
//  Uses on-device AI for natural language parsing + PythonServiceManager for real search.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class AISearchViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published private(set) var suggestions: [String] = []
    @Published private(set) var curatedResults: [SearchResult] = []
    @Published private(set) var insights: [String] = []
    @Published private(set) var fullResults: MusicSearchResults = MusicSearchResults()
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var searchProgress: Double = 0
    @Published private(set) var errorMessage: String?

    private let pythonService = PythonServiceManager.shared
    private var searchTask: Task<Void, Never>?
    private var progressCleanupTask: Task<Void, Never>?

    // Apple Intelligence availability (for UI binding)
    var isAppleIntelligenceAvailable: Bool {
        if #available(macOS 26.0, *) {
            return FoundationModelsService.shared.isAvailable
        }
        return false
    }

    var isAppleIntelligenceNotReady: Bool {
        if #available(macOS 26.0, *) {
            let service = FoundationModelsService.shared
            return !service.isDisabledByUser && !service.isAvailable
        }
        return true
    }

    func bootstrap(initialQuery: String?) {
        guard let initialQuery, inputText.isEmpty else { return }
        inputText = initialQuery
    }

    func submitCurrentQuery(limit: Int = 20) {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchTask?.cancel()
            searchTask = nil
            stopProgress(immediate: true)
            isSearching = false
            errorMessage = nil
            resetOutputs()
            return
        }

        searchTask?.cancel()
        stopProgress(immediate: true)
        isSearching = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            guard let self else { return }
            await self.performSearch(for: trimmed, limit: limit)
        }
    }

    func useSuggestion(_ suggestion: String, limit: Int = 20) {
        inputText = suggestion
        submitCurrentQuery(limit: limit)
    }

    func clear() {
        cancelTasks()
        inputText = ""
        isSearching = false
        errorMessage = nil
        resetOutputs()
    }

    private func performSearch(for query: String, limit: Int) async {
        defer { searchTask = nil }

        isSearching = true
        errorMessage = nil
        startProgressAnimation()

        do {
            // Try Apple Intelligence path on macOS 26+
            if #available(macOS 26.0, *) {
                let service = FoundationModelsService.shared
                if service.isAvailable {
                    let intent = try await parseIntentWithAI(query: query)
                    if Task.isCancelled { return }

                    let searchQuery = intent.buildSearchQuery()
                    let searchResponse = try await executeSearch(query: searchQuery, limit: limit)
                    if Task.isCancelled { return }

                    // Build AI-powered suggestions from the parsed intent
                    var aiSuggestions: [String] = []
                    if !intent.artist.isEmpty { aiSuggestions.append("More by \(intent.artist)") }
                    if !intent.mood.isEmpty { aiSuggestions.append("\(intent.mood.capitalized) \(intent.genre.isEmpty ? "music" : intent.genre)") }
                    if !intent.era.isEmpty { aiSuggestions.append("\(normalizeEra(intent.era)) \(intent.genre.isEmpty ? "hits" : intent.genre)") }
                    if !intent.activity.isEmpty { aiSuggestions.append("More \(intent.activity) music") }
                    if aiSuggestions.isEmpty { aiSuggestions.append("Top hits like this") }

                    var aiInsights: [String] = []
                    aiInsights.append("Playing: \(intent.queryDescription())")
                    if !intent.artist.isEmpty { aiInsights.append("Featured artist: \(intent.artist)") }

                    suggestions = aiSuggestions
                    insights = aiInsights
                    curatedResults = Array(searchResponse.songs.prefix(6))
                    fullResults = searchResponse
                    errorMessage = nil

                    isSearching = false
                    stopProgress(immediate: false, success: true)
                    return
                }
            }

            // Fallback: regular search without AI
            let searchResponse = try await executeSearch(query: query, limit: limit)
            if Task.isCancelled { return }

            suggestions = []
            insights = []
            curatedResults = Array(searchResponse.songs.prefix(6))
            fullResults = searchResponse
            errorMessage = nil

            isSearching = false
            stopProgress(immediate: false, success: true)
        } catch is CancellationError {
            isSearching = false
            stopProgress(immediate: true)
        } catch {
            if Task.isCancelled { return }
            isSearching = false
            stopProgress(immediate: false, success: false)
            errorMessage = message(for: error)
            suggestions = []
            curatedResults = []
            insights = []
            fullResults = MusicSearchResults()
        }
    }

    @available(macOS 26.0, *)
    private func parseIntentWithAI(query: String) async throws -> MusicIntent {
        let service = FoundationModelsService.shared
        let searchTool = MusicSearchTool()
        let instructions = FoundationModelsPromptLibrary.commandBarInstructions()

        guard let session = service.createCommandSession(
            instructions: instructions,
            tools: [searchTool]
        ) else {
            throw AIError.notAvailable
        }

        let intent = try await session.respond(to: query, generating: MusicIntent.self)
        return intent.content
    }

    private func executeSearch(query: String, limit: Int) async throws -> MusicSearchResults {
        try pythonService.ensureServiceRunning()
        return try await pythonService.searchMusic(query: query, limit: limit)
    }

    private func normalizeEra(_ era: String) -> String {
        let lowered = era.lowercased()
        if lowered.contains("1960") { return "60s" }
        if lowered.contains("1970") { return "70s" }
        if lowered.contains("1980") { return "80s" }
        if lowered.contains("1990") { return "90s" }
        if lowered.contains("2000") { return "2000s" }
        if lowered.contains("2010") { return "2010s" }
        if lowered.contains("2020") { return "2020s" }
        return era
    }

    private func startProgressAnimation() {
        progressCleanupTask?.cancel()
        searchProgress = 0

        // One declarative ramp replaces an ~8 Hz task that hopped to the main actor
        // on every tick — and kept waking even after the value had capped at 0.92.
        // SwiftUI interpolates this on the render thread with no timer wakeups.
        withAnimation(.easeOut(duration: 8.0)) {
            searchProgress = 0.92
        }
    }

    private func stopProgress(immediate: Bool, success: Bool = false) {

        if immediate {
            progressCleanupTask?.cancel()
            progressCleanupTask = nil
            let target = success ? 1.0 : 0.0
            withAnimation(.easeOut(duration: 0.2)) {
                searchProgress = target
            }
            return
        }

        if success {
            withAnimation(.easeOut(duration: 0.2)) {
                searchProgress = 1
            }

            progressCleanupTask?.cancel()
            progressCleanupTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, !self.isSearching else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.searchProgress = 0
                    }
                    self.progressCleanupTask = nil
                }
            }
        } else {
            progressCleanupTask?.cancel()
            progressCleanupTask = nil
            withAnimation(.easeOut(duration: 0.2)) {
                searchProgress = 0
            }
        }
    }

    private func resetOutputs() {
        suggestions = []
        curatedResults = []
        insights = []
        fullResults = MusicSearchResults()
    }

    private func cancelTasks() {
        searchTask?.cancel()
        searchTask = nil
        stopProgress(immediate: true)
        isSearching = false
    }

    private func message(for error: Error) -> String {
        if #available(macOS 26.0, *) {
            if let msg = AIErrorHandler.handleAndMessage(error) {
                return msg
            }
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
