import Foundation

struct Person: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var mentions: Int
    var lastSeen: Date?

    init(id: UUID = UUID(), name: String, mentions: Int = 0, lastSeen: Date? = nil) {
        self.id = id
        self.name = name
        self.mentions = mentions
        self.lastSeen = lastSeen
    }
}
