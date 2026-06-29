import Foundation

actor EmbeddingService {
    static let shared = EmbeddingService()

    private let providerService: LLMProviderService

    init(providerService: LLMProviderService = .shared) {
        self.providerService = providerService
    }

    func vector(for text: String) async -> [Float]? {
        try? await providerService.embedding.embed(text: text)
    }

    func similarity(between a: [Float], and b: [Float]) -> Float {
        providerService.embedding.similarity(between: a, and: b)
    }

    var currentDimensions: Int {
        providerService.embedding.dimensions
    }
}
