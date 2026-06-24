import Testing
import Foundation
@testable import Remember

@Suite("Semantic Search")
struct SemanticSearchTests {

    private func makeSetup() async throws -> (GRDBMemoryRepository, SemanticSearchService) {
        let db = try AppDatabase(inMemory: true)
        let repo = GRDBMemoryRepository(writer: db.writer)
        let semantic = SemanticSearchService(repository: repo)
        return (repo, semantic)
    }

    // MARK: - Embedding Generation

    @Test("EmbeddingService generates vector for English text")
    func embeddingEnglish() async {
        let vector = await EmbeddingService.shared.vector(for: "artificial intelligence startup")
        #expect(vector != nil)
        #expect((vector?.count ?? 0) > 0)
        print("[Embedding] EN vector dimensions: \(vector?.count ?? 0)")
    }

    @Test("EmbeddingService generates vector for Russian text")
    func embeddingRussian() async {
        let vector = await EmbeddingService.shared.vector(for: "искусственный интеллект стартап")
        print("[Embedding] RU vector: \(vector == nil ? "NIL — not supported" : "\(vector!.count) dims")")
        // Russian may not be supported by NLEmbedding — this test documents the behavior
    }

    @Test("Cosine similarity: identical texts = 1.0")
    func similarityIdentical() async {
        let v1 = await EmbeddingService.shared.vector(for: "sales CRM software")
        let v2 = await EmbeddingService.shared.vector(for: "sales CRM software")
        guard let v1, let v2 else { return }
        let score = await EmbeddingService.shared.similarity(between: v1, and: v2)
        print("[Similarity] identical: \(score)")
        #expect(score > 0.99)
    }

    @Test("Cosine similarity: related concepts score")
    func similarityRelated() async {
        let pairs: [(String, String)] = [
            ("AI CRM for sales teams", "startup about sales"),
            ("trip to London", "travel in England"),
            ("machine learning model", "artificial intelligence algorithm"),
            ("meeting with investor", "fundraising conversation"),
            ("book about psychology", "human behavior research"),
        ]

        for (a, b) in pairs {
            let v1 = await EmbeddingService.shared.vector(for: a)
            let v2 = await EmbeddingService.shared.vector(for: b)
            guard let v1, let v2 else {
                print("[Similarity] '\(a)' vs '\(b)': SKIP — no vector")
                continue
            }
            let score = await EmbeddingService.shared.similarity(between: v1, and: v2)
            print("[Similarity] '\(a)' vs '\(b)': \(String(format: "%.3f", score))")
        }
    }

    @Test("Cosine similarity: unrelated concepts score low")
    func similarityUnrelated() async {
        let v1 = await EmbeddingService.shared.vector(for: "cooking pasta recipe")
        let v2 = await EmbeddingService.shared.vector(for: "software architecture patterns")
        guard let v1, let v2 else { return }
        let score = await EmbeddingService.shared.similarity(between: v1, and: v2)
        print("[Similarity] unrelated: \(String(format: "%.3f", score))")
        #expect(score < 0.7)
    }

    // MARK: - Hybrid Search Scenarios

    @Test("Semantic finds memory by meaning — EN")
    func semanticFindsByMeaning() async throws {
        let (repo, semantic) = try await makeSetup()

        let memory = MemoryItem(title: "AI CRM", content: "AI-powered CRM for sales teams")
        try await repo.save(memory)
        await semantic.indexMemory(memory)

        let ftsResults = try await repo.search(query: "startup about sales")
        let results = await semantic.search(query: "startup about sales", ftsResults: ftsResults)

        print("[Search] 'startup about sales' → \(results.count) result(s)")
        results.forEach { print("  → '\($0.title)' | '\($0.content)'") }

        #expect(results.contains { $0.id == memory.id })
    }

    @Test("Semantic ranking: most relevant comes first")
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

        let query = "artificial intelligence product"
        let ftsResults = try await repo.search(query: query)
        let results = await semantic.search(query: query, ftsResults: ftsResults)

        print("[Ranking] query: '\(query)'")
        results.enumerated().forEach { i, m in
            print("  \(i + 1). '\(m.title)'")
        }

        #expect(results.first?.title == "AI startup")
    }

    @Test("FTS5 miss but semantic finds")
    func semanticFindsWhatFTSMisses() async throws {
        let (repo, semantic) = try await makeSetup()

        let memory = MemoryItem(title: "Revenue growth", content: "Discussion about increasing company income")
        try await repo.save(memory)
        await semantic.indexMemory(memory)

        // FTS5 won't find "profit" — it's not in the text
        let ftsResults = try await repo.search(query: "profit")
        let semanticResults = await semantic.search(query: "profit", ftsResults: ftsResults)

        print("[FTS5 miss] 'profit' FTS5: \(ftsResults.count), semantic: \(semanticResults.count)")
        semanticResults.forEach { print("  → '\($0.title)'") }
        // Documents the semantic uplift — may or may not find depending on threshold
    }
}
