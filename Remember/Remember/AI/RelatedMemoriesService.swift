import Foundation

actor RelatedMemoriesService {
    private let repository: any MemoryRepository
    private let embedding: EmbeddingService

    init(repository: any MemoryRepository, embedding: EmbeddingService = .shared) {
        self.repository = repository
        self.embedding = embedding
    }

    /// Returns up to `limit` memories related to the given memory,
    /// ranked by semantic similarity among entity-matched candidates.
    func findRelated(to memory: MemoryItem, limit: Int = 5) async -> [MemoryItem] {
        let entities = (try? await repository.fetchEntities(for: memory.id)) ?? []
        let entityValues = entities.map(\.value)

        var candidates = (try? await repository.fetchMemories(withEntityValues: entityValues)) ?? []
        candidates.removeAll { $0.id == memory.id }

        guard !candidates.isEmpty else { return [] }

        let sourceText = memory.title + " " + memory.content
        guard let sourceVector = await embedding.vector(for: sourceText) else {
            return Array(candidates.prefix(limit))
        }

        var ranked: [(MemoryItem, Float)] = []
        for candidate in candidates {
            let candidateText = candidate.title + " " + candidate.content
            if let v = await embedding.vector(for: candidateText) {
                let score = await embedding.similarity(between: sourceVector, and: v)
                ranked.append((candidate, score))
            }
        }

        return ranked
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}
