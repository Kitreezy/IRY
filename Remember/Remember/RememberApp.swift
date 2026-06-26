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

    private func indexUnindexedMemories() async {
        let all = (try? await repository.fetchAll()) ?? []
        let indexed = Set((try? await repository.fetchAllEmbeddings())?.map { $0.memoryId } ?? [])
        let unindexed = all.filter { !indexed.contains($0.id) }
        for memory in unindexed {
            await semantic.indexMemory(memory)
        }
    }

    private func extractEntitiesForUnprocessed() async {
        guard entityExtraction.isAvailable else { return }
        let all = (try? await repository.fetchAll()) ?? []
        let processed = Set((try? await repository.fetchAllEntities())?.map { $0.memoryId } ?? [])
        let unprocessed = all.filter { !processed.contains($0.id) }
        for memory in unprocessed {
            await entityExtraction.extractAndSave(for: memory)
        }
    }
}
