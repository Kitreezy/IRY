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
        guard let entities = await extract(for: memory), !entities.isEmpty else { return }
        try? await repository.saveEntities(entities)
    }

    /// Пакетное извлечение сущностей.
    ///
    /// Извлечение для каждого воспоминания независимо, поэтому запускаем
    /// параллельно. Окно намеренно узкое (`onDeviceLLM`): модель Foundation
    /// Models одна на устройство, и лавина запросов только удлиняет очередь.
    /// Запись в БД делается одним вызовом после — вместо N транзакций.
    @discardableResult
    func extractAndSave(for memories: [MemoryItem]) async -> Int {
        guard extractor.isAvailable, !memories.isEmpty else { return 0 }

        let extractor = self.extractor
        let batches = await memories.concurrentCompactMap(maxConcurrent: ConcurrencyLimit.onDeviceLLM) { memory in
            let text = Self.extractionText(for: memory)
            return try? await extractor.extract(from: text, memoryId: memory.id)
        }

        let entities = batches.flatMap { $0 }
        guard !entities.isEmpty else { return 0 }
        try? await repository.saveEntities(entities)
        return entities.count
    }

    // MARK: - Private

    private func extract(for memory: MemoryItem) async -> [MemoryEntity]? {
        try? await extractor.extract(from: Self.extractionText(for: memory), memoryId: memory.id)
    }

    private static func extractionText(for memory: MemoryItem) -> String {
        "\(memory.title). \(memory.content)"
    }
}
