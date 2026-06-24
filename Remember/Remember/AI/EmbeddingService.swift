import Foundation
import NaturalLanguage

actor EmbeddingService {
    static let shared = EmbeddingService()

    private let embedding: NLEmbedding?

    private init() {
        embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    func vector(for text: String) -> [Float]? {
        guard let embedding,
              let vector = embedding.vector(for: text.lowercased()) else { return nil }
        return vector.map { Float($0) }
    }

    func similarity(between a: [Float], and b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(Float(0)) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(Float(0)) { $0 + $1 * $1 })
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }
}
