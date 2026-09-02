import Foundation

actor EmbeddingService {
    static let shared = EmbeddingService()

    private let providerService: LLMProviderService

    init(providerService: LLMProviderService = .shared) {
        self.providerService = providerService
    }

    func vector(for text: String) async -> [Float]? {
        try? await providerService.embedding.embed(text: text)
    }

    /// Считает векторы для нескольких текстов параллельно.
    ///
    /// Последовательный вариант ждал ответа на каждый текст по очереди:
    /// суммарное время = сумма латентностей. Здесь время ≈ сумма / `maxConcurrent`.
    /// Порядок результатов совпадает с порядком `texts`.
    func vectors(for texts: [String], maxConcurrent: Int = ConcurrencyLimit.network) async -> [[Float]?] {
        // Провайдер достаётся один раз: он Sendable, а его создание читает Keychain.
        let provider = providerService.embedding
        return await texts.concurrentMap(maxConcurrent: maxConcurrent) { text in
            try? await provider.embed(text: text)
        }
    }

    /// Чистая математика — без состояния, поэтому `nonisolated`:
    /// вызов не переключается на актор и не сериализует параллельные задачи.
    nonisolated func similarity(between a: [Float], and b: [Float]) -> Float {
        Self.cosineSimilarity(a, b)
    }

    nonisolated static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }

    var currentDimensions: Int {
        providerService.embedding.dimensions
    }
}
