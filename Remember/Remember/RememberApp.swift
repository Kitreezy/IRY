import SwiftUI

@main
struct RememberApp: App {
    private let repository: any MemoryRepository = GRDBMemoryRepository(
        pool: AppDatabase.shared.pool
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.memoryRepository, repository)
        }
    }
}
