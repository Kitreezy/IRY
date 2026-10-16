import Foundation

actor SemanticSearchService {
    private let embedding: EmbeddingService
    private let repository: any MemoryRepository

    init(repository: any MemoryRepository, embedding: EmbeddingService = .shared) {
        self.repository = repository
        self.embedding = embedding
    }

    // Generate and store embedding when a memory is saved
    func indexMemory(_ memory: MemoryItem) async {
        let text = Self.indexText(for: memory)
        guard let vector = await embedding.vector(for: text) else { return }
        try? await repository.saveEmbedding(memoryId: memory.id, embedding: vector)
    }

    /// Что пора пересчитать: без вектора или с вектором не той модели,
    /// которой текущий провайдер посчитал бы этот текст. Так переиндексация
    /// после смены провайдера, обновления модели Apple или правки текста на
    /// другом языке происходит сама — без кнопки в настройках.
    func memoriesNeedingIndex(_ memories: [MemoryItem]) async -> [MemoryItem] {
        let stored = Dictionary(
            ((try? await repository.fetchAllEmbeddings()) ?? []).map { ($0.memoryId, $0.embedding.model) },
            uniquingKeysWith: { first, _ in first }
        )
        var stale: [MemoryItem] = []
        for memory in memories {
            let wanted = await embedding.model(for: Self.indexText(for: memory))
            if stored[memory.id] != wanted {
                stale.append(memory)
            }
        }
        return stale
    }

    /// Re-index memories.
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
            try? await repository.saveEmbedding(memoryId: memory.id, embedding: vector)
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
        let threshold = await embedding.threshold(for: queryVector.model)

        // Независимые чтения из БД — запускаем одновременно.
        async let embeddingsTask = try? await repository.fetchAllEmbeddings()
        async let allMemoriesTask = try? await repository.fetchAll()
        let allEmbeddings = await embeddingsTask ?? []
        let allMemories = await allMemoriesTask ?? []

        guard !allEmbeddings.isEmpty else { return ftsResults }

        // Косинусное сходство — чистая математика без актора: цикл больше не
        // делает hop на EmbeddingService на каждой итерации.
        //
        // Сравниваются только векторы той же модели, что и запрос: у других
        // моделей другое пространство. На устройстве это значит, что русский
        // запрос ищет среди русских воспоминаний, английский — среди
        // английских; английское по-русски находит полнотекстовый поиск.
        var scores: [UUID: Float] = [:]
        scores.reserveCapacity(allEmbeddings.count)

        for (memoryId, stored) in allEmbeddings where stored.model == queryVector.model {
            scores[memoryId] = EmbeddingService.cosineSimilarity(queryVector.vector, stored.vector)
        }

        // Смысловых совпадений — не больше трёх лучших, и только выше порога.
        // Одного порога мало: у модели на устройстве несвязанные фразы
        // похожи на 0.6–0.7, и по порогу в выдачу шло полколлекции. Замер
        // (Tools/bench-embeddings.sh) — F1 0.25 по порогу, 0.49 с ограничением.
        let semanticIds = Set(
            scores.filter { $0.value >= threshold }
                .sorted { $0.value > $1.value }
                .prefix(Self.maxSemanticHits)
                .map(\.key)
        )

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

    /// Сколько воспоминаний добавляет смысловой поиск к полнотекстовому.
    static let maxSemanticHits = 3

    // MARK: - Private

    private static func indexText(for memory: MemoryItem) -> String {
        [memory.title, memory.content, memory.why]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
