import Foundation
import FoundationModels

// MARK: - Apple Text Completion (iOS 26+)

@available(iOS 26.0, *)
actor AppleTextCompletionProvider: TextCompletionProvider {
    let providerName = "Apple Foundation Models"

    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func complete(prompt: String) async throws -> String {
        guard isAvailable else { throw LLMError.notAvailable }
        let session = LanguageModelSession(model: .default)
        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Fallbacks

struct UnavailableTextCompletionProvider: TextCompletionProvider {
    let providerName = "Unavailable"
    let isAvailable = false
    func complete(prompt: String) async throws -> String { throw LLMError.notAvailable }
}
