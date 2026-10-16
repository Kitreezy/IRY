import Foundation
import NaturalLanguage

/// Эмбеддинги на устройстве — контекстной моделью NaturalLanguage.
///
/// Раньше на устройстве работала `NLEmbedding.sentenceEmbedding(for: .english)`
/// — для любого текста. Русский она не знает: «собака лает» оказывалась
/// ближе к «налоговой декларации» (0.856), чем к «пёс гавкает» (0.846), и
/// смысловой поиск по-русски был случайным. Поэтому для русского
/// приходилось уходить в облако.
///
/// `NLContextualEmbedding` — модель-трансформер Apple, своя на каждый
/// алфавит: латиница, кириллица, китайские иероглифы и так далее. Она даёт
/// вектор на каждый токен; вектор текста — их среднее.
///
/// Отсюда главное ограничение: векторы разных алфавитов несравнимы. Русский
/// запрос не найдёт английское воспоминание — облачная модель, одна на все
/// языки, это умела. Поэтому у вектора есть метка модели, и сравниваются
/// только векторы одной модели.
///
/// Модель — общий ресурс, а не чистая функция: актор сериализует доступ,
/// как и в прежнем провайдере (параллельные вызовы портили кучу).
actor OnDeviceEmbeddingProvider: EmbeddingProvider {
    nonisolated let providerName = "Apple NaturalLanguage (on-device)"

    /// Модели есть почти для всех языков; есть ли для этого текста — видно
    /// только при расчёте, и тогда `embed` бросает `notAvailable`.
    nonisolated let isAvailable = true

    /// Загруженные модели — по идентификатору: одна модель обслуживает
    /// весь алфавит, и грузить её на каждый язык незачем.
    private var loaded: [String: NLContextualEmbedding] = [:]

    func model(for text: String) async -> String {
        guard let embedding = NLContextualEmbedding(language: Self.language(of: text)) else {
            return "nl.contextual.none"
        }
        return Self.modelID(of: embedding)
    }

    func embed(text: String) async throws -> TextEmbedding {
        let language = Self.language(of: text)
        guard let embedding = try await ready(for: language) else {
            throw LLMError.notAvailable
        }

        // Длиннее предела модель не читает: хвост отрезается заранее, по
        // символам с запасом — токен кириллицы в среднем три-четыре знака.
        let limit = embedding.maximumSequenceLength * 3
        let input = text.count > limit ? String(text.prefix(limit)) : text

        let result = try embedding.embeddingResult(for: input, language: language)
        var sum = [Double](repeating: 0, count: embedding.dimension)
        var tokens = 0
        result.enumerateTokenVectors(in: input.startIndex..<input.endIndex) { vector, _ in
            for index in vector.indices {
                sum[index] += vector[index]
            }
            tokens += 1
            return true
        }
        guard tokens > 0 else {
            throw LLMError.invalidResponse
        }
        return TextEmbedding(vector: sum.map { Float($0 / Double(tokens)) },
                             model: Self.modelID(of: embedding))
    }

    nonisolated func threshold(for model: String) -> Float {
        // Подобрано замером (Tools/bench-embeddings.sh): у среднего по
        // токенам высокий фон — несвязанные фразы дают 0.6–0.7, — поэтому
        // порог сам по себе отделяет плохо и работает только вместе с
        // ограничением выдачи тремя лучшими (SemanticSearchService).
        Self.contextualThreshold
    }

    static let contextualThreshold: Float = 0.68

    // MARK: - Модель

    /// Модель для языка — загруженная и готовая. Ресурсов нет на устройстве
    /// — просим систему скачать; не вышло — `nil`, и поиск остаётся
    /// полнотекстовым.
    private func ready(for language: NLLanguage) async throws -> NLContextualEmbedding? {
        guard let embedding = NLContextualEmbedding(language: language) else {
            return nil
        }
        if let cached = loaded[embedding.modelIdentifier] {
            return cached
        }
        if !embedding.hasAvailableAssets {
            guard try await embedding.requestAssets() == .available else {
                return nil
            }
        }
        try embedding.load()
        loaded[embedding.modelIdentifier] = embedding
        return embedding
    }

    /// Метка модели с ревизией: обновит Apple модель — векторы станут
    /// другими, и старые надо будет пересчитать.
    private static func modelID(of embedding: NLContextualEmbedding) -> String {
        "nl.contextual.\(embedding.modelIdentifier).r\(embedding.revision)"
    }

    /// Язык текста. Не распознан — английский: короткие и смешанные
    /// заметки чаще всего латиницей.
    static func language(of text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else {
            return .english
        }
        return language
    }
}
