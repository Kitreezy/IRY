import Foundation
import NaturalLanguage
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

// MARK: - Apple Embedding (NLEmbedding, iOS 18+)

// NLEmbedding is immutable after init and thread-safe for reads — @unchecked Sendable is safe here.
final class AppleEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    let providerName = "Apple NLEmbedding"
    let dimensions = 512
    let isAvailable: Bool

    private let embedding: NLEmbedding?

    init() {
        let emb = NLEmbedding.sentenceEmbedding(for: .english)
        self.embedding = emb
        self.isAvailable = emb != nil
    }

    func embed(text: String) async throws -> [Float] {
        guard let embedding else { throw LLMError.notAvailable }
        guard let vector = embedding.vector(for: text.lowercased()) else {
            throw LLMError.invalidResponse
        }
        return vector.map { Float($0) }
    }
}

// MARK: - Fallbacks

struct UnavailableTextCompletionProvider: TextCompletionProvider {
    let providerName = "Unavailable"
    let isAvailable = false
    func complete(prompt: String) async throws -> String { throw LLMError.notAvailable }
}
