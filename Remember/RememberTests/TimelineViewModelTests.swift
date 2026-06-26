import Testing
import Foundation
@testable import Remember

@Suite("Timeline")
@MainActor
struct TimelineViewModelTests {
    private func makeRepo() throws -> GRDBMemoryRepository {
        let db = try AppDatabase(inMemory: true)
        return GRDBMemoryRepository(writer: db.writer)
    }

    @Test("empty repo yields no sections")
    func emptySections() async throws {
        let repo = try makeRepo()
        let vm = TimelineViewModel(repository: repo)
        await vm.load()
        #expect(vm.sections.isEmpty)
    }

    @Test("memories are grouped into sections by day")
    func groupedByDay() async throws {
        let repo = try makeRepo()
        let calendar = Calendar.current

        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let m1 = MemoryItem(title: "A", content: "today 1", source: .userCreated, createdAt: today)
        let m2 = MemoryItem(title: "B", content: "today 2", source: .userCreated, createdAt: today)
        let m3 = MemoryItem(title: "C", content: "yesterday", source: .userCreated, createdAt: yesterday)

        try await repo.save(m1)
        try await repo.save(m2)
        try await repo.save(m3)

        let vm = TimelineViewModel(repository: repo)
        await vm.load()

        #expect(vm.sections.count == 2)
        let todaySection = vm.sections.first
        #expect(todaySection?.memories.count == 2)
        let yesterdaySection = vm.sections.last
        #expect(yesterdaySection?.memories.count == 1)
    }

    @Test("sections are sorted newest first")
    func sectionsSortedNewestFirst() async throws {
        let repo = try makeRepo()
        let calendar = Calendar.current
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        try await repo.save(MemoryItem(title: "Old", content: "old", createdAt: twoDaysAgo))
        try await repo.save(MemoryItem(title: "New", content: "new", createdAt: today))

        let vm = TimelineViewModel(repository: repo)
        await vm.load()

        #expect(vm.sections.first?.memories.first?.title == "New")
        #expect(vm.sections.last?.memories.first?.title == "Old")
    }

    @Test("memories within a section are sorted newest first")
    func memoriesWithinSectionSortedNewestFirst() async throws {
        let repo = try makeRepo()
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)

        try await repo.save(MemoryItem(title: "Earlier", content: "e", createdAt: earlier))
        try await repo.save(MemoryItem(title: "Later", content: "l", createdAt: now))

        let vm = TimelineViewModel(repository: repo)
        await vm.load()

        let section = try #require(vm.sections.first)
        #expect(section.memories.first?.title == "Later")
    }

    @Test("today section label is 'Today'")
    func todayLabel() async throws {
        let repo = try makeRepo()
        try await repo.save(MemoryItem(title: "T", content: "t", createdAt: Date()))

        let vm = TimelineViewModel(repository: repo)
        await vm.load()

        #expect(vm.sections.first?.formattedDate == L10n.Timeline.today)
    }
}

// MARK: - MemoryItem convenience init for tests

private extension MemoryItem {
    init(title: String, content: String, source: MemorySource = .userCreated, createdAt: Date) {
        self.init(id: UUID(), title: title, content: content, source: source,
                  createdAt: createdAt, updatedAt: createdAt, tags: [])
    }
}
