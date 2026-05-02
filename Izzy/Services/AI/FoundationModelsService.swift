//
//  FoundationModelsService.swift
//  Izzy
//
//  Apple Intelligence on-device AI service for natural language music commands.
//  Ported from kaset (https://github.com/sozercan/kaset)
//

import Foundation
import FoundationModels
import Observation
import os

// MARK: - FoundationModelsPromptBudget

@available(macOS 26.0, *)
struct FoundationModelsPromptBudget: Equatable {
    let contextSize: Int
    let instructionsTokens: Int
    let promptTokens: Int
    let toolsTokens: Int
    let schemaTokens: Int

    var totalTokens: Int {
        instructionsTokens + promptTokens + toolsTokens + schemaTokens
    }

    var remainingTokens: Int {
        max(0, contextSize - totalTokens)
    }

    var utilizationPercent: Int {
        guard contextSize > 0 else { return 0 }
        return Int((Double(totalTokens) / Double(contextSize) * 100).rounded())
    }
}

// MARK: - FoundationModelsService

@available(macOS 26.0, *)
@MainActor
@Observable
final class FoundationModelsService {
    static let shared = FoundationModelsService()

    private(set) var availability: SystemLanguageModel.Availability = .unavailable(.modelNotReady)
    private(set) var isWarmedUp: Bool = false

    var isDisabledByUser: Bool = false {
        didSet {
            UserDefaults.standard.set(isDisabledByUser, forKey: Self.disabledKey)
            NotificationCenter.default.post(name: Notification.Name.intelligenceAvailabilityChanged, object: nil)
        }
    }

    var isAvailable: Bool {
        guard !isDisabledByUser else { return false }
        return availability == .available
    }

    private static let disabledKey = "intelligence.disabled"

    private init() {
        isDisabledByUser = UserDefaults.standard.bool(forKey: Self.disabledKey)
    }

    func warmup() async {
        availability = SystemLanguageModel.default.availability

        switch availability {
        case .available:
            prewarmSession()
        case let .unavailable(reason):
            print("🤖 Foundation Models unavailable: \(String(describing: reason))")
        @unknown default:
            break
        }

        isWarmedUp = true
    }

    func createCommandSession(instructions: String, tools: [any Tool]) -> LanguageModelSession? {
        guard isAvailable else { return nil }
        return LanguageModelSession(
            tools: tools,
            instructions: instructions
        )
    }

    func createAnalysisSession(instructions: String) -> LanguageModelSession? {
        guard isAvailable else { return nil }
        return LanguageModelSession(instructions: instructions)
    }

    func clearContext() {
        // Sessions are created fresh each time
    }

    private func prewarmSession() {
        let session = LanguageModelSession()
        session.prewarm()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let intelligenceAvailabilityChanged = Notification.Name("intelligenceAvailabilityChanged")
}
