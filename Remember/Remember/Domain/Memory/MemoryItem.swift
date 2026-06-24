import Foundation

struct MemoryItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var source: MemorySource
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        source: MemorySource = .userCreated,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
    }
}
