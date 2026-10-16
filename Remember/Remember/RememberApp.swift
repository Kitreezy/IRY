import SwiftUI

@main
struct RememberApp: App {
    private let repository: any MemoryRepository
    private let semantic: SemanticSearchService
    private let entityExtraction: EntityExtractionService
    private let importService: ImportService

    init() {
        let repo = GRDBMemoryRepository(writer: AppDatabase.shared.writer)
        self.repository = repo
        self.semantic = SemanticSearchService(repository: repo)
        self.importService = ImportService(repository: repo)

        let extractor: any EntityExtracting
        if #available(iOS 26.0, *) {
            extractor = FoundationModelsExtractor()
        } else {
            extractor = UnavailableEntityExtractor()
        }
        self.entityExtraction = EntityExtractionService(extractor: extractor, repository: repo)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.memoryRepository, repository)
                .environment(\.entityExtractionService, entityExtraction)
                .environment(\.importService, importService)
                .task { await seedIfNeeded() }
                .task { await indexUnindexedMemories() }
                .task { await extractEntitiesForUnprocessed() }
        }
    }

    // MARK: - Seed (DEBUG only)

    private func seedIfNeeded() async {
        #if DEBUG
        let all = (try? await repository.fetchAll()) ?? []
        guard all.isEmpty else { return }
        for memory in SeedData.memories {
            try? await repository.save(memory)
        }
        #endif
    }

    // MARK: - Background indexing

    /// Две `.task` выше стартуют независимо, поэтому индексация и извлечение
    /// сущностей идут одновременно. Внутри каждой — тоже параллелизм.
    private func indexUnindexedMemories() async {
        // Не только новые: вектор чужой модели тоже устарел — после смены
        // провайдера или обновления модели Apple.
        let all = (try? await repository.fetchAll()) ?? []
        let stale = await semantic.memoriesNeedingIndex(all)
        await semantic.reindexAll(memories: stale)
    }

    private func extractEntitiesForUnprocessed() async {
        guard entityExtraction.isAvailable else { return }

        async let allTask = try? await repository.fetchAll()
        async let processedTask = try? await repository.fetchAllEntities()

        let all = await allTask ?? []
        let processed = Set((await processedTask)?.map { $0.memoryId } ?? [])

        let unprocessed = all.filter { !processed.contains($0.id) }
        await entityExtraction.extractAndSave(for: unprocessed)
    }
}
