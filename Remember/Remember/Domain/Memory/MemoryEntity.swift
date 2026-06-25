import Foundation

struct MemoryEntity: Identifiable, Hashable, Sendable {
    let id: UUID
    let memoryId: UUID
    var value: String
    var type: EntityType

    init(id: UUID = UUID(), memoryId: UUID, value: String, type: EntityType) {
        self.id = id
        self.memoryId = memoryId
        self.value = value
        self.type = type
    }
}

enum EntityType: String, Codable, Hashable, Sendable {
    case person
    case place
    case topic
    case company
}
