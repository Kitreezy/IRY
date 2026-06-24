import SwiftUI

private struct MemoryRepositoryKey: EnvironmentKey {
    static let defaultValue: any MemoryRepository = GRDBMemoryRepository(
        writer: AppDatabase.shared.writer
    )
}

extension EnvironmentValues {
    var memoryRepository: any MemoryRepository {
        get { self[MemoryRepositoryKey.self] }
        set { self[MemoryRepositoryKey.self] = newValue }
    }
}
