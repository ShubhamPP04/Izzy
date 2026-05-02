//
//  AIErrorHandler.swift
//  Izzy
//
//  Maps Foundation Models errors to user-friendly messages.
//  Ported from kaset (https://github.com/sozercan/kaset)
//

import Foundation
import FoundationModels

enum AIError: LocalizedError {
    case contextWindowExceeded
    case contentBlocked
    case cancelled
    case notAvailable
    case modelNotReady
    case sessionBusy
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .contextWindowExceeded: "The request is too long for on-device processing."
        case .contentBlocked: "Content was blocked by safety filters."
        case .cancelled: "Request was cancelled."
        case .notAvailable: "Apple Intelligence is not available on this device."
        case .modelNotReady: "The on-device model is still loading. Please try again."
        case .sessionBusy: "AI is busy processing another request. Please wait."
        case .unknown(let message): message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .contextWindowExceeded: "Try a shorter or simpler request."
        case .contentBlocked: "Rephrase your request."
        case .cancelled: nil
        case .notAvailable: "Apple Intelligence requires a compatible Mac with macOS 26+."
        case .modelNotReady: "Wait a moment and try again."
        case .sessionBusy: "Wait for the current request to finish."
        case .unknown: nil
        }
    }

    var shouldDisplay: Bool {
        switch self {
        case .cancelled: false
        default: true
        }
    }
}

@available(macOS 26.0, *)
enum AIErrorHandler {
    @MainActor
    static func handle(_ error: Error) -> AIError {
        if let genError = error as? LanguageModelSession.GenerationError {
            return handleGenerationError(genError)
        }
        if error is CancellationError {
            return .cancelled
        }
        return .unknown(error.localizedDescription)
    }

    @MainActor
    static func handleGenerationError(_ error: LanguageModelSession.GenerationError) -> AIError {
        switch error {
        case .exceededContextWindowSize:
            return .contextWindowExceeded
        case .guardrailViolation:
            return .contentBlocked
        case .assetsUnavailable:
            return .notAvailable
        case .unsupportedGuide:
            return .notAvailable
        case .unsupportedLanguageOrLocale:
            return .notAvailable
        case .decodingFailure:
            return .unknown("Failed to parse AI response. Try rephrasing.")
        case .rateLimited:
            return .sessionBusy
        case .concurrentRequests:
            return .sessionBusy
        case .refusal:
            return .contentBlocked
        @unknown default:
            return .unknown(error.localizedDescription)
        }
    }

    static func userMessage(for error: AIError) -> String {
        var parts = [error.errorDescription ?? "Unknown error"]
        if let suggestion = error.recoverySuggestion {
            parts.append(suggestion)
        }
        return parts.joined(separator: " ")
    }

    @MainActor
    static func handleAndMessage(_ error: Error) -> String? {
        let aiError = handle(error)
        guard aiError.shouldDisplay else { return nil }
        return userMessage(for: aiError)
    }
}
