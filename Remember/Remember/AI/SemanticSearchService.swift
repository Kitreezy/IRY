import Foundation

actor SemanticSearchService {
    private let embedding = EmbeddingService.shared
    private let repository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    // Generate and store embedding when a memory is saved
    func indexMemory(_ memory: MemoryItem) async {
        let text = "\(memory.title) \(memory.content)"
        guard let vector = await embedding.vector(for: text) else { return }
        try? await repository.saveEmbedding(memoryId: memory.id, vector: vector)
    }

    // Hybrid search: FTS5 union + semantic reranking
    func search(query: String, ftsResults: [MemoryItem]) async -> [MemoryItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ftsResults
        }

        guard let queryVector = await embedding.vector(for: query) else {
            return ftsResults
        }

        let allEmbeddings = (try? await repository.fetchAllEmbeddings()) ?? []
        guard !allEmbeddings.isEmpty else { return ftsResults }

        // Score all embeddings against query
        let threshold: Float = 0.55
        var semanticIds = Set<UUID>()
        var scores: [UUID: Float] = [:]

        for (memoryId, vector) in allEmbeddings {
            let score = await embedding.similarity(between: queryVector, and: vector)
            scores[memoryId] = score
            if score >= threshold {
                semanticIds.insert(memoryId)
            }
        }

        // FTS5 ids
        let ftsIds = Set(ftsResults.map { $0.id })

        // Union: FTS5 + semantic hits
        let unionIds = ftsIds.union(semanticIds)

        // Fetch all memories in union that aren't already in ftsResults
        let allMemories = (try? await repository.fetchAll()) ?? []
        let semanticOnly = allMemories.filter { semanticIds.contains($0.id) && !ftsIds.contains($0.id) }
        let combined = ftsResults + semanticOnly

        // Rerank by score (semantic score takes priority, fallback to 0)
        return combined
            .filter { unionIds.contains($0.id) }
            .sorted { a, b in
                (scores[a.id] ?? 0) > (scores[b.id] ?? 0)
            }
    }
}
