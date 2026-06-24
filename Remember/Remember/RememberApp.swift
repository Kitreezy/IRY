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
        }
    }
}
