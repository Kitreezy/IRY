import Foundation

// MARK: - Sync State

enum SyncState: Sendable, Equatable {
    case idle
    case syncing
    case succeeded(at: Date)
    case failed(Error)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): true
        case (.syncing, .syncing): true
        case (.succeeded(let a), .succeeded(let b)): a == b
        case (.failed, .failed): true
        default: false
        }
    }
}

// MARK: - Protocol

/// Abstracts cloud sync so CloudKit can be swapped without touching call sites.
/// Requires a paid Apple Developer account for the real implementation.
protocol SyncService: Actor {
    var state: SyncState { get }

    /// Push all local changes to the cloud.
    func push() async throws

    /// Pull remote changes and merge into local storage.
    func pull() async throws

    /// Full bidirectional sync: pull then push.
    func sync() async throws
}
