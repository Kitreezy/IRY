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

    /// Гибридный поиск: полнотекстовая выдача и смысловая, слитые по местам.
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

        // Смысловых совпадений — не больше нескольких лучших, и только выше
        // порога: у модели на устройстве несвязанные фразы похожи на
        // 0.6–0.7, и по одному порогу в выдачу шло полколлекции.
        let semanticRanked = scores.filter { $0.value >= threshold }
            .sorted { $0.value > $1.value }
            .prefix(Self.maxSemanticHits)
            .map(\.key)

        return Self.fuse(fts: ftsResults, semantic: semanticRanked, all: allMemories)
    }

    /// Слияние двух выдач по местам — Reciprocal Rank Fusion.
    ///
    /// Раньше всё сортировалось по косинусу, и точное совпадение по словам
    /// уходило ниже случайного смыслового. Складывать bm25 и косинус
    /// нельзя — у них разные шкалы, — поэтому складываются места: каждый
    /// список даёт `1 / (k + место)`. Найденное обоими способами — выше
    /// найденного одним, а первое в любом списке — выше десятого.
    static func fuse(fts: [MemoryItem], semantic: [UUID], all: [MemoryItem]) -> [MemoryItem] {
        let ftsRank = Dictionary(fts.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let semanticRank = Dictionary(semantic.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        func score(_ id: UUID) -> Double {
            [ftsRank[id], semanticRank[id]].compactMap { $0 }.reduce(0) { $0 + 1 / (fusionK + Double($1 + 1)) }
        }

        let byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            .merging(fts.map { ($0.id, $0) }, uniquingKeysWith: { _, fresh in fresh })
        // Равные суммы — обычное дело: первое место в одном списке весит
        // столько же, сколько первое в другом. Порядок равных задаётся явно —
        // раньше он зависел от словаря, и одна и та же выдача менялась от
        // запуска к запуску. Слово надёжнее смысла: полнотекстовое — первым.
        let never = Int.max
        return Set(ftsRank.keys).union(semanticRank.keys)
            .sorted { a, b in
                let (sa, sb) = (score(a), score(b))
                if sa != sb { return sa > sb }
                if ftsRank[a, default: never] != ftsRank[b, default: never] {
                    return ftsRank[a, default: never] < ftsRank[b, default: never]
                }
                return semanticRank[a, default: never] < semanticRank[b, default: never]
            }
            .compactMap { byId[$0] }
    }

    /// Насколько первые места важнее следующих: чем меньше, тем сильнее.
    /// Обычно берут 60; на коротких выдачах 1–10 чуть лучше, 60 — чуть хуже.
    static let fusionK: Double = 10

    /// Сколько воспоминаний добавляет смысловой поиск к полнотекстовому.
    /// Пять дают выдачу длиннее при том же качестве (Tools/bench-search.sh).
    static let maxSemanticHits = 3

    // MARK: - Private

    private static func indexText(for memory: MemoryItem) -> String {
        [memory.title, memory.content, memory.why]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
