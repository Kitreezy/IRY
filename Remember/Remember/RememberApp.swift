import SwiftUI

@main
struct RememberApp: App {
    private let repository: any MemoryRepository = GRDBMemoryRepository(
        writer: AppDatabase.shared.writer
    )
    private let semantic: SemanticSearchService

    init() {
        let repo = GRDBMemoryRepository(writer: AppDatabase.shared.writer)
        self.semantic = SemanticSearchService(repository: repo)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.memoryRepository, repository)
                .task { await seedIfNeeded() }
                .task { await indexUnindexedMemories() }
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

    // Indexes any memory that has no embedding yet.
    // Runs on every launch — safe to call multiple times (skips already-indexed).
    private func indexUnindexedMemories() async {
        let all = (try? await repository.fetchAll()) ?? []
        let indexed = Set((try? await repository.fetchAllEmbeddings())?.map { $0.memoryId } ?? [])
        let unindexed = all.filter { !indexed.contains($0.id) }
        for memory in unindexed {
            await semantic.indexMemory(memory)
        }
    }
}
