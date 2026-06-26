import Testing
import Foundation
@testable import Remember

@Suite("Related Memories")
struct RelatedMemoriesTests {
    private func makeRepo() throws -> GRDBMemoryRepository {
        let db = try AppDatabase(inMemory: true)
        return GRDBMemoryRepository(writer: db.writer)
    }

    @Test("returns empty when memory has no entities")
    func noEntities() async throws {
        let repo = try makeRepo()
        let memory = MemoryItem(title: "Solo", content: "No entities here")
        try await repo.save(memory)

        let service = RelatedMemoriesService(repository: repo)
        let result = await service.findRelated(to: memory)
        #expect(result.isEmpty)
    }

    @Test("finds memory sharing same person entity")
    func findsBySharedPerson() async throws {
        let repo = try makeRepo()

        let m1 = MemoryItem(title: "Meeting with Sergey", content: "Discussed funding")
        let m2 = MemoryItem(title: "Dinner with Sergey", content: "Talked about startup")
        let m3 = MemoryItem(title: "Random note", content: "Nothing related")

        try await repo.save(m1)
        try await repo.save(m2)
        try await repo.save(m3)

        let e1 = MemoryEntity(id: UUID(), memoryId: m1.id, value: "Sergey", type: .person)
        let e2 = MemoryEntity(id: UUID(), memoryId: m2.id, value: "Sergey", type: .person)
        try await repo.saveEntities([e1, e2])

        let service = RelatedMemoriesService(repository: repo)
        let result = await service.findRelated(to: m1)

        #expect(result.count == 1)
        #expect(result.first?.id == m2.id)
    }

    @Test("excludes the source memory from results")
    func excludesSourceMemory() async throws {
        let repo = try makeRepo()
        let memory = MemoryItem(title: "London trip", content: "Visited London")
        try await repo.save(memory)

        let entity = MemoryEntity(id: UUID(), memoryId: memory.id, value: "London", type: .place)
        try await repo.saveEntities([entity])

        let service = RelatedMemoriesService(repository: repo)
        let result = await service.findRelated(to: memory)

        #expect(!result.contains { $0.id == memory.id })
    }

    @Test("respects limit parameter")
    func respectsLimit() async throws {
        let repo = try makeRepo()
        let source = MemoryItem(title: "Source", content: "About London")
        try await repo.save(source)
        let sourceEntity = MemoryEntity(id: UUID(), memoryId: source.id, value: "London", type: .place)
        try await repo.saveEntities([sourceEntity])

        for i in 1...6 {
            let m = MemoryItem(title: "Memory \(i)", content: "Also London \(i)")
            try await repo.save(m)
            let e = MemoryEntity(id: UUID(), memoryId: m.id, value: "London", type: .place)
            try await repo.saveEntities([e])
        }

        let service = RelatedMemoriesService(repository: repo)
        let result = await service.findRelated(to: source, limit: 3)
        #expect(result.count <= 3)
    }

    @Test("finds memories sharing multiple entity types")
    func multipleEntityTypes() async throws {
        let repo = try makeRepo()
        let m1 = MemoryItem(title: "London with Sergey", content: "AI startup meeting")
        let m2 = MemoryItem(title: "Sergey in Berlin", content: "Another meeting")
        try await repo.save(m1)
        try await repo.save(m2)

        let e1 = MemoryEntity(id: UUID(), memoryId: m1.id, value: "Sergey", type: .person)
        let e2 = MemoryEntity(id: UUID(), memoryId: m1.id, value: "London", type: .place)
        let e3 = MemoryEntity(id: UUID(), memoryId: m2.id, value: "Sergey", type: .person)
        try await repo.saveEntities([e1, e2, e3])

        let service = RelatedMemoriesService(repository: repo)
        let result = await service.findRelated(to: m1)

        #expect(result.contains { $0.id == m2.id })
    }
}

private extension MemoryItem {
    init(title: String, content: String) {
        self.init(id: UUID(), title: title, content: content, source: .userCreated,
                  createdAt: Date(), updatedAt: Date(), tags: [])
    }
}
