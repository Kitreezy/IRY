import Foundation

actor EmbeddingService {
    static let shared = EmbeddingService()

    /// Текущий провайдер. Читается на каждый вызов: человек может сменить
    /// его в настройках, и следующий расчёт пойдёт уже новым.
    private let current: @Sendable () -> any EmbeddingProvider

    init(providerService: LLMProviderService = .shared) {
        self.current = { providerService.embedding }
    }

    /// Конкретный провайдер — для тестов: моделей Apple в симуляторе нет.
    init(provider: any EmbeddingProvider) {
        self.current = { provider }
    }

    func vector(for text: String) async -> TextEmbedding? {
        try? await current().embed(text: text)
    }

    /// Какой моделью текущий провайдер посчитает текст.
    func model(for text: String) async -> String {
        await current().model(for: text)
    }

    /// Порог «близко» для модели — у каждой свой.
    func threshold(for model: String) -> Float {
        current().threshold(for: model)
    }

    /// Считает векторы для нескольких текстов параллельно.
    ///
    /// Последовательный вариант ждал ответа на каждый текст по очереди:
    /// суммарное время = сумма латентностей. Здесь время ≈ сумма / `maxConcurrent`.
    /// Порядок результатов совпадает с порядком `texts`.
    func vectors(for texts: [String], maxConcurrent: Int = ConcurrencyLimit.network) async -> [TextEmbedding?] {
        // Провайдер достаётся один раз: он Sendable, а его создание читает Keychain.
        let provider = current()
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
}
