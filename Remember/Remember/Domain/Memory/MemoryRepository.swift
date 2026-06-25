import Foundation

protocol MemoryRepository: Sendable {
    func save(_ memory: MemoryItem) async throws
    func fetch(id: UUID) async throws -> MemoryItem?
    func fetchAll() async throws -> [MemoryItem]
    func delete(id: UUID) async throws

    // FTS5
    func search(query: String) async throws -> [MemoryItem]

    // Semantic
    func saveEmbedding(memoryId: UUID, vector: [Float]) async throws
    func fetchAllEmbeddings() async throws -> [(memoryId: UUID, vector: [Float])]

    // Entities
    func saveEntities(_ entities: [MemoryEntity]) async throws
    func fetchEntities(for memoryId: UUID) async throws -> [MemoryEntity]
    func fetchAllEntities() async throws -> [MemoryEntity]
    func fetchEntities(ofType type: EntityType) async throws -> [MemoryEntity]
}
