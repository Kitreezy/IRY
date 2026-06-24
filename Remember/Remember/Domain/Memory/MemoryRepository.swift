import Foundation

protocol MemoryRepository: Sendable {
    func save(_ memory: MemoryItem) async throws
    func fetch(id: UUID) async throws -> MemoryItem?
    func fetchAll() async throws -> [MemoryItem]
    func delete(id: UUID) async throws
    func search(query: String) async throws -> [MemoryItem]
}
