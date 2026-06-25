import Testing
import Foundation
@testable import Remember

// MARK: - Mock

private actor MockEntityExtractor: EntityExtracting {
    nonisolated var isAvailable: Bool { true }

    func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity] {
        // Simulates what Foundation Models would return
        var entities: [MemoryEntity] = []

        if text.contains("Sergey") || text.contains("Сергей") {
            entities.append(MemoryEntity(memoryId: memoryId, value: "Sergey", type: .person))
        }
        if text.contains("London") || text.contains("Лондон") {
            entities.append(MemoryEntity(memoryId: memoryId, value: "London", type: .place))
        }
        if text.contains("AI CRM") {
            entities.append(MemoryEntity(memoryId: memoryId, value: "AI CRM", type: .topic))
        }
        if text.contains("Flint Capital") {
            entities.append(MemoryEntity(memoryId: memoryId, value: "Flint Capital", type: .company))
        }

        return entities
    }
}

// MARK: - Tests

@Suite("Entity Extraction")
struct EntityExtractionTests {
    private func makeSetup() async throws -> (GRDBMemoryRepository, EntityExtractionService) {
        let db = try AppDatabase(inMemory: true)
        let repo = GRDBMemoryRepository(writer: db.writer)
        let service = EntityExtractionService(extractor: MockEntityExtractor(), repository: repo)
        return (repo, service)
    }

    @Test("Extracts person from memory")
    func extractsPerson() async throws {
        let (repo, service) = try await makeSetup()
        let memory = MemoryItem(
            title: "Call with Sergey",
            content: "Discussed AI CRM launch with Sergey"
        )
        try await repo.save(memory)
        await service.extractAndSave(for: memory)

        let entities = try await repo.fetchEntities(for: memory.id)
        let people = entities.filter { $0.type == .person }

        print("[Entity] people: \(people.map(\.value))")
        #expect(people.contains { $0.value == "Sergey" })
    }

    @Test("Extracts place from memory")
    func extractsPlace() async throws {
        let (repo, service) = try await makeSetup()
        let memory = MemoryItem(
            title: "London trip",
            content: "Planning a trip to London in September"
        )
        try await repo.save(memory)
        await service.extractAndSave(for: memory)

        let entities = try await repo.fetchEntities(for: memory.id)
        let places = entities.filter { $0.type == .place }

        print("[Entity] places: \(places.map(\.value))")
        #expect(places.contains { $0.value == "London" })
    }

    @Test("Extracts company from memory")
    func extractsCompany() async throws {
        let (repo, service) = try await makeSetup()
        let memory = MemoryItem(
            title: "Investor meeting",
            content: "Meeting with Mikhail from Flint Capital"
        )
        try await repo.save(memory)
        await service.extractAndSave(for: memory)

        let entities = try await repo.fetchEntities(for: memory.id)
        let companies = entities.filter { $0.type == .company }

        print("[Entity] companies: \(companies.map(\.value))")
        #expect(companies.contains { $0.value == "Flint Capital" })
    }

    @Test("fetchEntities(ofType:) filters correctly")
    func fetchByType() async throws {
        let (repo, service) = try await makeSetup()

        let m1 = MemoryItem(title: "Call with Sergey", content: "AI CRM discussion with Sergey")
        let m2 = MemoryItem(title: "London trip", content: "Going to London")

        for m in [m1, m2] {
            try await repo.save(m)
            await service.extractAndSave(for: m)
        }

        let people = try await repo.fetchEntities(ofType: .person)
        let places = try await repo.fetchEntities(ofType: .place)

        print("[Entity] all people: \(people.map(\.value))")
        print("[Entity] all places: \(places.map(\.value))")

        #expect(people.allSatisfy { $0.type == .person })
        #expect(places.allSatisfy { $0.type == .place })
        #expect(!people.isEmpty)
        #expect(!places.isEmpty)
    }

    @Test("No entities saved when extractor unavailable")
    func skipsWhenUnavailable() async throws {
        let db = try AppDatabase(inMemory: true)
        let repo = GRDBMemoryRepository(writer: db.writer)

        struct UnavailableExtractor: EntityExtracting {
            nonisolated var isAvailable: Bool { false }
            func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity] { [] }
        }

        let service = EntityExtractionService(
            extractor: UnavailableExtractor(),
            repository: repo
        )
        let memory = MemoryItem(title: "Test", content: "Sergey London Flint Capital")
        try await repo.save(memory)
        await service.extractAndSave(for: memory)

        let entities = try await repo.fetchAllEntities()
        #expect(entities.isEmpty)
    }
}
