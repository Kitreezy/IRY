import SwiftUI

// MARK: - Environment Key

private struct MemoryRepositoryKey: EnvironmentKey {
    static let defaultValue: any MemoryRepository = GRDBMemoryRepository(
        pool: AppDatabase.shared.pool
    )
}

extension EnvironmentValues {
    var memoryRepository: any MemoryRepository {
        get { self[MemoryRepositoryKey.self] }
        set { self[MemoryRepositoryKey.self] = newValue }
    }
}
