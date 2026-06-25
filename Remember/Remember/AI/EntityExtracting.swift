import Foundation

protocol EntityExtracting: Sendable {
    func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity]
    var isAvailable: Bool { get }
}
