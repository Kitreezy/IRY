import Foundation
import GRDB

// MARK: - Records

private struct MemoryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "memory_items"

    var id: String
    var title: String
    var content: String
    var source: String
    var created_at: Date
    var updated_at: Date
    var tags: String

    init(from item: MemoryItem) {
        self.id = item.id.uuidString
        self.title = item.title
        self.content = item.content
        self.source = item.source.rawValue
        self.created_at = item.createdAt
        self.updated_at = item.updatedAt
        self.tags = item.tags.joined(separator: ",")
    }

    func toMemoryItem() -> MemoryItem? {
        guard let uuid = UUID(uuidString: id),
              let source = MemorySource(rawValue: source) else { return nil }
        let tagList = tags.isEmpty ? [] : tags.split(separator: ",").map(String.init)
        return MemoryItem(
            id: uuid,
            title: title,
            content: content,
            source: source,
            createdAt: created_at,
            updatedAt: updated_at,
            tags: tagList
        )
    }
}

private struct EmbeddingRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "memory_embeddings"

    var memory_id: String
    var vector: Data

    init(memoryId: UUID, vector: [Float]) {
        self.memory_id = memoryId.uuidString
        self.vector = vector.withUnsafeBytes { Data($0) }
    }

    func toVector() -> [Float] {
        vector.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

private struct EntityRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "memory_entities"

    var id: String
    var memory_id: String
    var value: String
    var type: String

    init(from entity: MemoryEntity) {
        self.id = entity.id.uuidString
        self.memory_id = entity.memoryId.uuidString
        self.value = entity.value
        self.type = entity.type.rawValue
    }

    func toEntity() -> MemoryEntity? {
        guard let id = UUID(uuidString: id),
              let memoryId = UUID(uuidString: memory_id),
              let type = EntityType(rawValue: type) else { return nil }
        return MemoryEntity(id: id, memoryId: memoryId, value: value, type: type)
    }
}

// MARK: - Repository

final class GRDBMemoryRepository: MemoryRepository {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    func save(_ memory: MemoryItem) async throws {
        let record = MemoryRecord(from: memory)
        try await writer.write { db in
            try record.save(db)
        }
    }

    func fetch(id: UUID) async throws -> MemoryItem? {
        try await writer.read { db in
            try MemoryRecord
                .filter(Column("id") == id.uuidString)
                .fetchOne(db)?
                .toMemoryItem()
        }
    }

    func fetchAll() async throws -> [MemoryItem] {
        try await writer.read { db in
            try MemoryRecord
                .order(Column("created_at").desc)
                .fetchAll(db)
                .compactMap { $0.toMemoryItem() }
        }
    }

    func delete(id: UUID) async throws {
        try await writer.write { db in
            try MemoryRecord
                .filter(Column("id") == id.uuidString)
                .deleteAll(db)
        }
    }

    func search(query: String) async throws -> [MemoryItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try await fetchAll()
        }
        let pattern = FTS5Pattern(matchingAllTokensIn: query)
        return try await writer.read { db in
            try MemoryRecord.fetchAll(
                db,
                sql: """
                    SELECT memory_items.*
                    FROM memory_items
                    JOIN memory_items_fts ON memory_items.rowid = memory_items_fts.rowid
                    WHERE memory_items_fts MATCH ?
                    ORDER BY memory_items.created_at DESC
                    """,
                arguments: [pattern]
            )
            .compactMap { $0.toMemoryItem() }
        }
    }

    func saveEmbedding(memoryId: UUID, vector: [Float]) async throws {
        let record = EmbeddingRecord(memoryId: memoryId, vector: vector)
        try await writer.write { db in
            try record.save(db)
        }
    }

    func fetchAllEmbeddings() async throws -> [(memoryId: UUID, vector: [Float])] {
        try await writer.read { db in
            try EmbeddingRecord.fetchAll(db).compactMap { record in
                guard let id = UUID(uuidString: record.memory_id) else { return nil }
                return (memoryId: id, vector: record.toVector())
            }
        }
    }

    // MARK: - Entities

    func saveEntities(_ entities: [MemoryEntity]) async throws {
        try await writer.write { db in
            for entity in entities {
                let record = EntityRecord(from: entity)
                try record.save(db)
            }
        }
    }

    func fetchEntities(for memoryId: UUID) async throws -> [MemoryEntity] {
        try await writer.read { db in
            try EntityRecord
                .filter(Column("memory_id") == memoryId.uuidString)
                .fetchAll(db)
                .compactMap { $0.toEntity() }
        }
    }

    func fetchAllEntities() async throws -> [MemoryEntity] {
        try await writer.read { db in
            try EntityRecord.fetchAll(db).compactMap { $0.toEntity() }
        }
    }

    func fetchEntities(ofType type: EntityType) async throws -> [MemoryEntity] {
        try await writer.read { db in
            try EntityRecord
                .filter(Column("type") == type.rawValue)
                .fetchAll(db)
                .compactMap { $0.toEntity() }
        }
    }

    func fetchMemories(withEntityValues values: [String]) async throws -> [MemoryItem] {
        guard !values.isEmpty else { return [] }
        let placeholders = values.map { _ in "?" }.joined(separator: ", ")
        let args = StatementArguments(values)
        return try await writer.read { db in
            try MemoryRecord.fetchAll(
                db,
                sql: """
                    SELECT DISTINCT memory_items.*
                    FROM memory_items
                    JOIN memory_entities ON memory_items.id = memory_entities.memory_id
                    WHERE memory_entities.value IN (\(placeholders))
                    ORDER BY memory_items.created_at DESC
                    """,
                arguments: args
            )
            .compactMap { $0.toMemoryItem() }
        }
    }

    func fetchEmbedding(for memoryId: UUID) async throws -> [Float]? {
        try await writer.read { db in
            try EmbeddingRecord
                .filter(Column("memory_id") == memoryId.uuidString)
                .fetchOne(db)?
                .toVector()
        }
    }
}
