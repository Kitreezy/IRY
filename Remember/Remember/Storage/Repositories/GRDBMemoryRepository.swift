import Foundation
import GRDB

// MARK: - GRDB Record

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
}
