//
//  AISearchViewModel.swift
//  Izzy
//
//  Created by GitHub Copilot on 26/09/25.
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
    private var progressTask: Task<Void, Never>?
    private var progressCleanupTask: Task<Void, Never>?

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

        guard pythonService.hasGeminiAPIKey else {
            isSearching = false
            resetOutputs()
            errorMessage = "Add your Gemini API key in Settings to enable AI Search."
            stopProgress(immediate: true)
            return
        }

        isSearching = true
        errorMessage = nil
        startProgressAnimation()

        do {
            try pythonService.ensureServiceRunning()
            let response = try await pythonService.performAISearch(query: query, limit: limit)

            if Task.isCancelled {
                isSearching = false
                stopProgress(immediate: true)
                return
            }

            inputText = response.query
            suggestions = response.suggestions
            curatedResults = response.topResults
            insights = response.insights ?? []
            fullResults = response.results
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

    private func startProgressAnimation() {
        progressTask?.cancel()
        progressCleanupTask?.cancel()
        searchProgress = 0

        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    guard let self, self.isSearching else { return }
                    let increment = Double.random(in: 0.04...0.08)
                    let nextValue = min(self.searchProgress + increment, 0.92)
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.searchProgress = nextValue
                    }
                }
            }
        }
    }

    private func stopProgress(immediate: Bool, success: Bool = false) {
        progressTask?.cancel()
        progressTask = nil

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
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
