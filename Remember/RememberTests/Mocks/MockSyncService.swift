import Foundation
@testable import Remember

actor MockSyncService: SyncService {
    private(set) var state: SyncState = .idle

    var pushCallCount = 0
    var pullCallCount = 0
    var shouldFail = false
    var remoteMemories: [MemoryItem] = []

    private let repository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func push() async throws {
        pushCallCount += 1
        state = .syncing
        if shouldFail {
            state = .failed(MockSyncError.forced)
            throw MockSyncError.forced
        }
        state = .succeeded(at: Date())
    }

    func pull() async throws {
        pullCallCount += 1
        state = .syncing
        if shouldFail {
            state = .failed(MockSyncError.forced)
            throw MockSyncError.forced
        }
        for memory in remoteMemories {
            try await repository.save(memory)
        }
        state = .succeeded(at: Date())
    }

    func sync() async throws {
        try await pull()
        try await push()
    }

    func set(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }

    func set(remoteMemories: [MemoryItem]) {
        self.remoteMemories = remoteMemories
    }
}

enum MockSyncError: Error {
    case forced
}
