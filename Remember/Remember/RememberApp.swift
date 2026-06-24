import SwiftUI

@main
struct RememberApp: App {
    private let repository: any MemoryRepository = GRDBMemoryRepository(
        writer: AppDatabase.shared.writer
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.memoryRepository, repository)
                .task { await seedIfNeeded() }
        }
    }

    private func seedIfNeeded() async {
        #if DEBUG
        guard let count = try? await repository.fetchAll(), count.isEmpty else { return }
        for memory in SeedData.memories {
            try? await repository.save(memory)
        }
        #endif
    }
}
