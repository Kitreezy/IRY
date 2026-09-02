import Foundation

actor SemanticSearchService {
    private let embedding = EmbeddingService.shared
    private let repository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    // Generate and store embedding when a memory is saved
    func indexMemory(_ memory: MemoryItem) async {
        let text = Self.indexText(for: memory)
        guard let vector = await embedding.vector(for: text) else { return }
        try? await repository.saveEmbedding(memoryId: memory.id, vector: vector)
    }

    /// Re-index all memories — needed when switching embedding providers
    /// (different dimensions are incompatible).
    ///
    /// Каждое воспоминание независимо от остальных, поэтому векторы считаются
    /// параллельно. Раньше 200 воспоминаний по 300 мс = ~60 с; при окне в 4
    /// задачи — ~15 с. Запись в БД идёт после, чтобы не держать транзакции
    /// открытыми во время сетевых ожиданий.
    @discardableResult
    func reindexAll(memories: [MemoryItem], maxConcurrent: Int = ConcurrencyLimit.network) async -> Int {
        guard !memories.isEmpty else { return 0 }

        let texts = memories.map(Self.indexText(for:))
        let vectors = await embedding.vectors(for: texts, maxConcurrent: maxConcurrent)

        var indexed = 0
        for (memory, vector) in zip(memories, vectors) {
            guard let vector else { continue }
            try? await repository.saveEmbedding(memoryId: memory.id, vector: vector)
            indexed += 1
        }
        return indexed
    }

    // Hybrid search: FTS5 union + semantic reranking
    func search(query: String, ftsResults: [MemoryItem]) async -> [MemoryItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ftsResults
        }

        guard let queryVector = await embedding.vector(for: query) else {
            return ftsResults
        }

        // Независимые чтения из БД — запускаем одновременно.
        async let embeddingsTask = try? await repository.fetchAllEmbeddings()
        async let allMemoriesTask = try? await repository.fetchAll()
        let allEmbeddings = await embeddingsTask ?? []
        let allMemories = await allMemoriesTask ?? []

        guard !allEmbeddings.isEmpty else { return ftsResults }

        // Косинусное сходство — чистая математика без актора: цикл больше не
        // делает hop на EmbeddingService на каждой итерации.
        let threshold: Float = 0.55
        var semanticIds = Set<UUID>()
        var scores: [UUID: Float] = [:]
        scores.reserveCapacity(allEmbeddings.count)

        for (memoryId, vector) in allEmbeddings {
            let score = EmbeddingService.cosineSimilarity(queryVector, vector)
            scores[memoryId] = score
            if score >= threshold {
                semanticIds.insert(memoryId)
            }
        }

        // FTS5 ids
        let ftsIds = Set(ftsResults.map { $0.id })

        // Union: FTS5 + semantic hits
        let unionIds = ftsIds.union(semanticIds)

        let semanticOnly = allMemories.filter { semanticIds.contains($0.id) && !ftsIds.contains($0.id) }
        let combined = ftsResults + semanticOnly

        // Rerank by score (semantic score takes priority, fallback to 0)
        return combined
            .filter { unionIds.contains($0.id) }
            .sorted { a, b in
                (scores[a.id] ?? 0) > (scores[b.id] ?? 0)
            }
    }

    // MARK: - Private

    private static func indexText(for memory: MemoryItem) -> String {
        [memory.title, memory.content, memory.why]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
