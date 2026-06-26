import Testing
import Foundation
@testable import Remember

// MARK: - Mock Importer

final class MockImporter: SourceImporter, @unchecked Sendable {
    let source: MemorySource
    var accessGranted: Bool
    var memoriesToImport: [MemoryItem]
    var shouldThrow: Bool

    init(
        source: MemorySource,
        accessGranted: Bool = true,
        memoriesToImport: [MemoryItem] = [],
        shouldThrow: Bool = false
    ) {
        self.source = source
        self.accessGranted = accessGranted
        self.memoriesToImport = memoriesToImport
        self.shouldThrow = shouldThrow
    }

    func requestAccess() async -> Bool { accessGranted }

    func importNew(into repository: any MemoryRepository) async throws -> Int {
        if shouldThrow { throw ImportError.testError }
        for memory in memoriesToImport {
            try await repository.save(memory)
        }
        return memoriesToImport.count
    }
}

enum ImportError: Error { case testError }

// MARK: - Tests

@Suite("ImportService")
struct ImportServiceTests {
    private func makeRepo() throws -> GRDBMemoryRepository {
        let db = try AppDatabase(inMemory: true)
        return GRDBMemoryRepository(writer: db.writer)
    }

    @Test("imports memories from granted source")
    func importsFromGrantedSource() async throws {
        let repo = try makeRepo()
        let memory = MemoryItem(title: "Team Meeting", content: "Q1 planning", source: .calendar)
        let importer = MockImporter(source: .calendar, accessGranted: true, memoriesToImport: [memory])
        let service = ImportService(repository: repo, importers: [importer])

        let results = await service.importAll()

        #expect(results.first?.imported == 1)
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.title == "Team Meeting")
    }

    @Test("skips import when access denied")
    func skipsWhenAccessDenied() async throws {
        let repo = try makeRepo()
        let memory = MemoryItem(title: "Private", content: "Content", source: .calendar)
        let importer = MockImporter(source: .calendar, accessGranted: false, memoriesToImport: [memory])
        let service = ImportService(repository: repo, importers: [importer])

        let results = await service.importAll()

        #expect(results.first?.imported == 0)
        let all = try await repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test("records failure when importer throws")
    func recordsFailure() async throws {
        let repo = try makeRepo()
        let importer = MockImporter(source: .calendar, accessGranted: true, shouldThrow: true)
        let service = ImportService(repository: repo, importers: [importer])

        let results = await service.importAll()

        #expect(results.first?.failed == 1)
        #expect(results.first?.imported == 0)
    }

    @Test("importFrom runs only the matching source")
    func importFromSpecificSource() async throws {
        let repo = try makeRepo()
        let calMemory = MemoryItem(title: "Event", content: "Calendar", source: .calendar)
        let photoMemory = MemoryItem(title: "Photo", content: "Photo", source: .photos)

        let calImporter = MockImporter(source: .calendar, memoriesToImport: [calMemory])
        let photoImporter = MockImporter(source: .photos, memoriesToImport: [photoMemory])
        let service = ImportService(repository: repo, importers: [calImporter, photoImporter])

        let result = await service.importFrom(.calendar)

        #expect(result.imported == 1)
        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.source == .calendar)
    }

    @Test("importAll runs all importers")
    func importAllRunsAll() async throws {
        let repo = try makeRepo()
        let calMemory = MemoryItem(title: "Event", content: "c", source: .calendar)
        let photoMemory = MemoryItem(title: "Photo day", content: "p", source: .photos)

        let calImporter = MockImporter(source: .calendar, memoriesToImport: [calMemory])
        let photoImporter = MockImporter(source: .photos, memoriesToImport: [photoMemory])
        let service = ImportService(repository: repo, importers: [calImporter, photoImporter])

        let results = await service.importAll()

        #expect(results.count == 2)
        #expect(results.map(\.imported).reduce(0, +) == 2)
        let all = try await repo.fetchAll()
        #expect(all.count == 2)
    }
}
