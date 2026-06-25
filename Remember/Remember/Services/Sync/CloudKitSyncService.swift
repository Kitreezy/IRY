import Foundation
import CloudKit

// MARK: - CloudKitSyncService
//
// ⚠️ Requires paid Apple Developer Program ($99/year).
// iCloud entitlement must be added in Xcode → Signing & Capabilities → iCloud → CloudKit.
// Container: iCloud.com.iry.remember
//
// Until the entitlement is provisioned this file compiles but all methods throw .notAvailable.

actor CloudKitSyncService: SyncService {
    private(set) var state: SyncState = .idle

    private let container: CKContainer
    private let repository: any MemoryRepository

    init(repository: any MemoryRepository, containerIdentifier: String = "iCloud.com.iry.remember") {
        self.repository = repository
        self.container = CKContainer(identifier: containerIdentifier)
    }

    // MARK: - SyncService

    func push() async throws {
        guard await isAccountAvailable() else { throw SyncError.notAvailable }
        state = .syncing
        do {
            let memories = try await repository.fetchAll()
            let records = memories.map { CKRecord(memoryItem: $0) }
            try await save(records: records)
            state = .succeeded(at: Date())
        } catch {
            state = .failed(error)
            throw error
        }
    }

    func pull() async throws {
        guard await isAccountAvailable() else { throw SyncError.notAvailable }
        state = .syncing
        do {
            let records = try await fetchAll()
            for record in records {
                if let memory = MemoryItem(record: record) {
                    try await repository.save(memory)
                }
            }
            state = .succeeded(at: Date())
        } catch {
            state = .failed(error)
            throw error
        }
    }

    func sync() async throws {
        try await pull()
        try await push()
    }

    // MARK: - Private

    private func isAccountAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    private func save(records: [CKRecord]) async throws {
        let db = container.privateCloudDatabase
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            db.add(operation)
        }
    }

    private func fetchAll() async throws -> [CKRecord] {
        let db = container.privateCloudDatabase
        let query = CKQuery(recordType: CKRecord.memoryRecordType, predicate: NSPredicate(value: true))
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (batch, nextCursor) = try await fetchBatch(db: db, query: query, cursor: cursor)
            records.append(contentsOf: batch)
            cursor = nextCursor
        } while cursor != nil

        return records
    }

    private func fetchBatch(
        db: CKDatabase,
        query: CKQuery,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> ([CKRecord], CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation = cursor.map { CKQueryOperation(cursor: $0) }
                ?? CKQueryOperation(query: query)
            var fetched: [CKRecord] = []

            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result { fetched.append(record) }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor): continuation.resume(returning: (fetched, nextCursor))
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            db.add(operation)
        }
    }
}

// MARK: - Errors

enum SyncError: Error, LocalizedError {
    case notAvailable
    case mappingFailed(UUID)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "iCloud account not available. Sign in to iCloud in Settings."
        case .mappingFailed(let id):
            "Failed to map memory \(id) to CloudKit record."
        }
    }
}
