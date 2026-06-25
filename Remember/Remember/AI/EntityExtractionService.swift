import Foundation

actor EntityExtractionService {
    private let extractor: any EntityExtracting
    private let repository: any MemoryRepository

    init(extractor: any EntityExtracting, repository: any MemoryRepository) {
        self.extractor = extractor
        self.repository = repository
    }

    nonisolated var isAvailable: Bool { extractor.isAvailable }

    func extractAndSave(for memory: MemoryItem) async {
        guard extractor.isAvailable else { return }
        let text = "\(memory.title). \(memory.content)"
        guard let entities = try? await extractor.extract(from: text, memoryId: memory.id),
              !entities.isEmpty else { return }
        try? await repository.saveEntities(entities)
    }
}
