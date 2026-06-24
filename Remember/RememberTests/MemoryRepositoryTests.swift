import Testing
import Foundation
@testable import Remember

@Suite("MemoryRepository")
struct MemoryRepositoryTests {
    private func makeRepository() throws -> GRDBMemoryRepository {
        let db = try AppDatabase(inMemory: true)
        return GRDBMemoryRepository(pool: db.pool)
    }

    @Test("Save and fetch by id")
    func saveAndFetch() async throws {
        let repo = try makeRepository()
        let memory = MemoryItem(title: "Test", content: "Hello world")

        try await repo.save(memory)
        let fetched = try await repo.fetch(id: memory.id)

        #expect(fetched?.id == memory.id)
        #expect(fetched?.title == "Test")
    }

    @Test("FTS5 search finds memory by content word")
    func searchByContent() async throws {
        let repo = try makeRepository()
        let memory = MemoryItem(title: "Startup idea", content: "AI-powered CRM for sales teams")

        try await repo.save(memory)
        let results = try await repo.search(query: "CRM")

        #expect(results.count == 1)
        #expect(results.first?.id == memory.id)
    }

    @Test("FTS5 search works in Russian")
    func searchRussian() async throws {
        let repo = try makeRepository()
        let memory = MemoryItem(title: "Заметка", content: "Обсуждали запуск стартапа с Сергеем")

        try await repo.save(memory)
        let results = try await repo.search(query: "стартап")

        #expect(results.count == 1)
    }

    @Test("Delete removes memory")
    func deleteMemory() async throws {
        let repo = try makeRepository()
        let memory = MemoryItem(title: "To delete", content: "Temporary")

        try await repo.save(memory)
        try await repo.delete(id: memory.id)
        let fetched = try await repo.fetch(id: memory.id)

        #expect(fetched == nil)
    }
}
