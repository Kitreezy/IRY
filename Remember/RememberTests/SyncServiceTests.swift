import Testing
import CloudKit
import Foundation
@testable import Remember

@Suite("SyncService")
struct SyncServiceTests {
    private func makeRepo() throws -> GRDBMemoryRepository {
        let db = try AppDatabase(inMemory: true)
        return GRDBMemoryRepository(writer: db.writer)
    }

    // MARK: - Initial State

    @Test("starts in idle state")
    func initialState() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        let state = await sync.state
        #expect(state == .idle)
    }

    // MARK: - Push

    @Test("push transitions to succeeded")
    func pushSucceeds() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        try await sync.push()
        let state = await sync.state
        guard case .succeeded = state else {
            Issue.record("Expected .succeeded, got \(state)")
            return
        }
    }

    @Test("push increments call count")
    func pushCallCount() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        try await sync.push()
        try await sync.push()
        let count = await sync.pushCallCount
        #expect(count == 2)
    }

    @Test("push failure transitions to failed state")
    func pushFails() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        await sync.set(shouldFail: true)
        do {
            try await sync.push()
            Issue.record("Expected throw")
        } catch {
            let state = await sync.state
            guard case .failed = state else {
                Issue.record("Expected .failed, got \(state)")
                return
            }
        }
    }

    // MARK: - Pull

    @Test("pull saves remote memories locally")
    func pullSavesRemoteMemories() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        let remote = MemoryItem(title: "Remote Memory", content: "From the cloud", source: .userCreated)
        await sync.set(remoteMemories: [remote])

        try await sync.pull()

        let saved = try await repo.fetch(id: remote.id)
        #expect(saved?.title == "Remote Memory")
    }

    @Test("pull with empty remote leaves local untouched")
    func pullEmptyRemote() async throws {
        let repo = try makeRepo()
        let local = MemoryItem(title: "Local", content: "Already here", source: .userCreated)
        try await repo.save(local)

        let sync = MockSyncService(repository: repo)
        try await sync.pull()

        let all = try await repo.fetchAll()
        #expect(all.count == 1)
    }

    // MARK: - Sync

    @Test("sync calls both pull and push")
    func syncCallsBoth() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        try await sync.sync()
        let pushCount = await sync.pushCallCount
        let pullCount = await sync.pullCallCount
        #expect(pushCount == 1)
        #expect(pullCount == 1)
    }

    @Test("sync failure on pull stops before push")
    func syncFailsOnPull() async throws {
        let repo = try makeRepo()
        let sync = MockSyncService(repository: repo)
        await sync.set(shouldFail: true)
        do {
            try await sync.sync()
            Issue.record("Expected throw")
        } catch {
            let pushCount = await sync.pushCallCount
            #expect(pushCount == 0)
        }
    }

    // MARK: - CKRecord Mapping

    @Test("MemoryItem round-trips through CKRecord")
    func ckRecordRoundTrip() throws {
        let original = MemoryItem(
            id: UUID(),
            title: "CloudKit test",
            content: "Sync content",
            source: .userCreated,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            updatedAt: Date(timeIntervalSince1970: 2_000_000),
            tags: ["swift", "cloudkit"]
        )
        let record = CKRecord(memoryItem: original)
        let restored = MemoryItem(record: record)

        #expect(restored?.id == original.id)
        #expect(restored?.title == original.title)
        #expect(restored?.content == original.content)
        #expect(restored?.source == original.source)
        #expect(restored?.tags == original.tags)
    }

    @Test("CKRecord with missing fields returns nil MemoryItem")
    func ckRecordMissingFields() throws {
        let record = CKRecord(recordType: CKRecord.memoryRecordType)
        let result = MemoryItem(record: record)
        #expect(result == nil)
    }
}

