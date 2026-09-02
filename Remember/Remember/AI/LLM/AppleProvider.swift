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

/// NLEmbedding — общий ресурс, а не чистая функция.
///
/// Раньше здесь стояло `@unchecked Sendable` с комментарием «thread-safe для
/// чтения». Как только векторы начали считаться параллельно, это привело к
/// `malloc: Heap corruption detected` — `vector(for:)` не рассчитан на
/// одновременные вызовы. Актор сериализует доступ к модели.
///
/// Вывод для параллелизма: on-device embeddings всё равно упираются в CPU,
/// поэтому выигрыш здесь минимален. Параллельная обработка окупается на
/// сетевых провайдерах (OpenAI / Gemini), где время — это ожидание ответа.
actor AppleEmbeddingProvider: EmbeddingProvider {
    nonisolated let providerName = "Apple NLEmbedding"
    nonisolated let dimensions = 512
    nonisolated let isAvailable: Bool

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
