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

        let sourceText = Self.rankingText(for: memory)
        let candidateTexts = candidates.map(Self.rankingText(for:))

        // Вектор исходного воспоминания и векторы кандидатов независимы —
        // считаем их одним параллельным заходом вместо N+1 последовательных.
        async let sourceVectorTask = embedding.vector(for: sourceText)
        async let candidateVectorsTask = embedding.vectors(for: candidateTexts)

        let sourceVector = await sourceVectorTask
        let candidateVectors = await candidateVectorsTask

        guard let sourceVector else {
            return Array(candidates.prefix(limit))
        }

        let ranked: [(MemoryItem, Float)] = zip(candidates, candidateVectors).compactMap { candidate, vector in
            guard let vector else { return nil }
            return (candidate, EmbeddingService.cosineSimilarity(sourceVector, vector))
        }

        return ranked
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    // MARK: - Private

    private static func rankingText(for memory: MemoryItem) -> String {
        memory.title + " " + memory.content
    }
}
