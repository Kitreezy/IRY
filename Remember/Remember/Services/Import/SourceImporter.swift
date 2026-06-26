import Foundation

// MARK: - Protocol

/// Imports memories from an external source (Calendar, Photos, etc.)
/// Each importer is responsible for requesting its own permissions.
protocol SourceImporter: Sendable {
    var source: MemorySource { get }

    /// Returns true if the user has granted access.
    func requestAccess() async -> Bool

    /// Fetches new items not yet saved in the repository.
    func importNew(into repository: any MemoryRepository) async throws -> Int
}

// MARK: - Import Result

struct ImportResult: Sendable {
    let source: MemorySource
    let imported: Int
    let failed: Int
}
