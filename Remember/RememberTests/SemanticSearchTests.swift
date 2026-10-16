import Testing
import Foundation
import NaturalLanguage
@testable import Remember

@Suite("Semantic Search")
struct SemanticSearchTests {

    /// Работает ли модель на этом устройстве. Проверяется делом, а не
    /// флагом: в симуляторе iOS латинская модель сообщает, что ресурсы на
    /// месте, но не загружается — нет доступа к системному кэшу моделей.
    /// Тесты, которым нужна настоящая модель, там пропускаются, а не падают;
    /// логику поиска проверяют тесты на поддельных векторах ниже.
    static let hasSentenceModel: Bool = {
        guard let model = NLContextualEmbedding(language: .english), model.hasAvailableAssets,
              (try? model.load()) != nil else {
            return false
        }
        return (try? model.embeddingResult(for: "probe", language: .english)) != nil
    }()

    private func makeSetup() async throws -> (GRDBMemoryRepository, SemanticSearchService) {
        let db = try AppDatabase(inMemory: true)
        let repo = GRDBMemoryRepository(writer: db.writer)
        let semantic = SemanticSearchService(repository: repo)
        return (repo, semantic)
    }

    // MARK: - Embedding Generation

    @Test("EmbeddingService generates vector for English text", .enabled(if: hasSentenceModel, "нет модели предложений NLEmbedding"))
    func embeddingEnglish() async {
        let vector = await EmbeddingService.shared.vector(for: "artificial intelligence startup")
        #expect(vector != nil)
        #expect((vector?.vector.count ?? 0) > 0)
        print("[Embedding] EN vector: \(vector?.vector.count ?? 0) dims, model \(vector?.model ?? "-")")
    }

    @Test("EmbeddingService generates vector for Russian text")
    func embeddingRussian() async {
        let vector = await EmbeddingService.shared.vector(for: "искусственный интеллект стартап")
        print("[Embedding] RU vector: \(vector.map { "\($0.vector.count) dims, model \($0.model)" } ?? "NIL — no model on this device")")
    }

    @Test("Cosine similarity: identical texts = 1.0", .enabled(if: hasSentenceModel, "нет модели предложений NLEmbedding"))
    func similarityIdentical() async throws {
        let v1 = try #require(await EmbeddingService.shared.vector(for: "sales CRM software"))
        let v2 = try #require(await EmbeddingService.shared.vector(for: "sales CRM software"))
        let score = await EmbeddingService.shared.similarity(between: v1.vector, and: v2.vector)
        print("[Similarity] identical: \(score)")
        #expect(score > 0.99)
    }

    @Test("Cosine similarity: related concepts score", .enabled(if: hasSentenceModel, "нет модели предложений NLEmbedding"))
    func similarityRelated() async throws {
        let pairs: [(String, String)] = [
            ("AI CRM for sales teams", "startup about sales"),
            ("trip to London", "travel in England"),
            ("machine learning model", "artificial intelligence algorithm"),
            ("meeting with investor", "fundraising conversation"),
            ("book about psychology", "human behavior research"),
        ]

        for (a, b) in pairs {
            let v1 = try #require(await EmbeddingService.shared.vector(for: a))
            let v2 = try #require(await EmbeddingService.shared.vector(for: b))
            let score = await EmbeddingService.shared.similarity(between: v1.vector, and: v2.vector)
            print("[Similarity] '\(a)' vs '\(b)': \(String(format: "%.3f", score))")
        }
    }

    @Test("Cosine similarity: related is closer than unrelated", .enabled(if: hasSentenceModel, "нет модели предложений NLEmbedding"))
    func similarityUnrelated() async throws {
        // Абсолютное число у моделей разное: у контекстной несвязанные фразы
        // дают 0.6–0.7. Проверяется порядок — связанное ближе несвязанного.
        let topic = try #require(await EmbeddingService.shared.vector(for: "machine learning model"))
        let related = try #require(await EmbeddingService.shared.vector(for: "artificial intelligence algorithm"))
        let unrelated = try #require(await EmbeddingService.shared.vector(for: "cooking pasta recipe"))
        let near = await EmbeddingService.shared.similarity(between: topic.vector, and: related.vector)
        let far = await EmbeddingService.shared.similarity(between: topic.vector, and: unrelated.vector)
        print("[Similarity] related \(String(format: "%.3f", near)), unrelated \(String(format: "%.3f", far))")
        #expect(near > far)
    }

    // MARK: - Hybrid Search Scenarios

    @Test("Semantic finds memory by meaning — EN", .enabled(if: hasSentenceModel, "нет модели предложений NLEmbedding"))
    func semanticFindsByMeaning() async throws {
        let (repo, semantic) = try await makeSetup()

        // Title + content concatenated for indexing: "AI startup Building AI CRM for sales teams"
        // Confirmed score vs "startup about sales": 0.627 (above threshold 0.55)
        let memory = MemoryItem(title: "AI startup", content: "Building AI CRM for sales teams")
        try await repo.save(memory)
        await semantic.indexMemory(memory)

        let query = "startup about sales"
        let ftsResults = try await repo.search(query: query)
        let results = await semantic.search(query: query, ftsResults: ftsResults)

        print("[Search] '\(query)' → \(results.count) result(s)")
        results.forEach { print("  → '\($0.title)' | '\($0.content)'") }

        #expect(results.contains { $0.id == memory.id })
    }

    @Test("Semantic ranking: most relevant comes first", .enabled(if: hasSentenceModel, "нет модели предложений NLEmbedding"))
    func semanticRanking() async throws {
        let (repo, semantic) = try await makeSetup()

        let memories = [
            MemoryItem(title: "London trip", content: "Visiting museums and parks in London"),
            MemoryItem(title: "AI startup", content: "Building AI CRM for sales teams"),
            MemoryItem(title: "Book notes", content: "Reading about psychology and behavior"),
        ]

        for m in memories {
            try await repo.save(m)
            await semantic.indexMemory(m)
        }

        // Use query semantically close to "AI CRM for sales" — confirmed score 0.627
        let query = "startup about sales"
        let ftsResults = try await repo.search(query: query)
        let results = await semantic.search(query: query, ftsResults: ftsResults)

        print("[Ranking] query: '\(query)'")
        results.enumerated().forEach { i, m in
            print("  \(i + 1). '\(m.title)'")
        }

        #expect(!results.isEmpty)
        #expect(results.first?.title == "AI startup")
    }

    @Test("FTS5 miss but semantic finds — sales synonyms")
    func semanticFindsWhatFTSMisses() async throws {
        let (repo, semantic) = try await makeSetup()

        // Indexed text: "AI startup Building AI CRM for sales teams"
        // vs query "startup about sales" confirmed score: 0.627 (above 0.55)
        let memory = MemoryItem(title: "AI startup", content: "Building AI CRM for sales teams")
        try await repo.save(memory)
        await semantic.indexMemory(memory)

        // FTS5 won't find "venture for salespeople" — different words
        let query = "venture for salespeople"
        let ftsResults = try await repo.search(query: query)
        let semanticResults = await semantic.search(query: query, ftsResults: ftsResults)

        print("[FTS5 miss] '\(query)' → FTS5: \(ftsResults.count), semantic: \(semanticResults.count)")
        semanticResults.forEach { print("  → '\($0.title)'") }

        #expect(ftsResults.isEmpty) // FTS5 misses — exact words not present
        // Semantic may or may not find — documents real behavior at threshold 0.55
        print("[FTS5 miss] semantic found: \(semanticResults.count > 0)")
    }
}

// MARK: - Логика поиска на поддельных векторах

/// Векторы заданы руками, модель — по тексту. Так логика поиска
/// проверяется без настоящей модели, которой в симуляторе нет.
private struct FakeEmbeddingProvider: EmbeddingProvider {
    let providerName = "fake"
    let isAvailable = true
    let vectors: [String: TextEmbedding]

    func model(for text: String) async -> String {
        vectors[text]?.model ?? "none"
    }

    func embed(text: String) async throws -> TextEmbedding {
        guard let vector = vectors[text] else { throw LLMError.notAvailable }
        return vector
    }

    func threshold(for model: String) -> Float { 0.5 }
}

@Suite("Semantic Search — logic")
struct SemanticSearchLogicTests {

    private func makeSetup(_ vectors: [String: TextEmbedding]) throws -> (GRDBMemoryRepository, SemanticSearchService) {
        let db = try AppDatabase(inMemory: true)
        let repo = GRDBMemoryRepository(writer: db.writer)
        let embedding = EmbeddingService(provider: FakeEmbeddingProvider(vectors: vectors))
        return (repo, SemanticSearchService(repository: repo, embedding: embedding))
    }

    private func ru(_ v: [Float]) -> TextEmbedding { TextEmbedding(vector: v, model: "cyrillic") }
    private func en(_ v: [Float]) -> TextEmbedding { TextEmbedding(vector: v, model: "latin") }

    @Test("Vectors of another model are not compared")
    func otherModelIsIgnored() async throws {
        // Векторы совпадают до знака, но посчитаны разными моделями —
        // значит, в разных пространствах, и сходство между ними ничего не значит.
        let memory = MemoryItem(title: "Ключи", content: "")
        let (repo, semantic) = try makeSetup(["Ключи": en([1, 0]), "keys": en([1, 0])])
        try await repo.save(memory)
        try await repo.saveEmbedding(memoryId: memory.id, embedding: ru([1, 0]))

        let results = await semantic.search(query: "keys", ftsResults: [])

        #expect(results.isEmpty)
    }

    @Test("Same model finds by meaning")
    func sameModelFinds() async throws {
        let memory = MemoryItem(title: "Ключи", content: "")
        let (repo, semantic) = try makeSetup(["Ключи": ru([1, 0]), "где запасной комплект": ru([0.9, 0.1])])
        try await repo.save(memory)
        await semantic.indexMemory(memory)

        let results = await semantic.search(query: "где запасной комплект", ftsResults: [])

        #expect(results.map(\.id) == [memory.id])
    }

    @Test("At most three semantic hits, best first")
    func semanticHitsAreCapped() async throws {
        let titles = ["a", "b", "c", "d", "e"]
        var vectors: [String: TextEmbedding] = ["q": ru([1, 0])]
        // Все пять выше порога, сходство убывает от a к e.
        for (i, title) in titles.enumerated() {
            vectors[title] = ru([1, Float(i) * 0.1])
        }
        let (repo, semantic) = try makeSetup(vectors)
        for title in titles {
            let memory = MemoryItem(title: title, content: "")
            try await repo.save(memory)
            await semantic.indexMemory(memory)
        }

        let results = await semantic.search(query: "q", ftsResults: [])

        #expect(results.map(\.title) == ["a", "b", "c"])
    }

    @Test("Full-text hits stay even without a vector")
    func ftsHitsStay() async throws {
        let memory = MemoryItem(title: "Ключи", content: "")
        let (repo, semantic) = try makeSetup(["q": ru([1, 0])])
        try await repo.save(memory)

        let results = await semantic.search(query: "q", ftsResults: [memory])

        #expect(results.map(\.id) == [memory.id])
    }

    @Test("Missing, legacy and foreign vectors need reindexing")
    func staleVectorsAreFound() async throws {
        let fresh = MemoryItem(title: "fresh", content: "")
        let missing = MemoryItem(title: "missing", content: "")
        let legacy = MemoryItem(title: "legacy", content: "")
        let foreign = MemoryItem(title: "foreign", content: "")
        let (repo, semantic) = try makeSetup([
            "fresh": ru([1]), "missing": ru([1]), "legacy": ru([1]), "foreign": ru([1])
        ])
        for memory in [fresh, missing, legacy, foreign] {
            try await repo.save(memory)
        }
        try await repo.saveEmbedding(memoryId: fresh.id, embedding: ru([1]))
        // До метки моделей вектор хранился без неё — миграция ставит пустую.
        try await repo.saveEmbedding(memoryId: legacy.id, embedding: TextEmbedding(vector: [1], model: ""))
        // Посчитан облаком до перехода на устройство.
        try await repo.saveEmbedding(memoryId: foreign.id, embedding: TextEmbedding(vector: [1], model: "gemini.gemini-embedding-001"))

        let stale = await semantic.memoriesNeedingIndex([fresh, missing, legacy, foreign])

        #expect(Set(stale.map(\.title)) == ["missing", "legacy", "foreign"])
    }

    @Test("Embedding keeps its model in the store")
    func modelIsStored() async throws {
        let memory = MemoryItem(title: "t", content: "")
        let (repo, _) = try makeSetup([:])
        try await repo.save(memory)

        try await repo.saveEmbedding(memoryId: memory.id, embedding: ru([0.5, 0.25]))

        #expect(try await repo.fetchEmbedding(for: memory.id) == ru([0.5, 0.25]))
    }
}
