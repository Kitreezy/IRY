import Foundation

struct MemoryItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var why: String        // Почему это важно — ключевое поле
    var summary: String    // AI-generated summary
    var source: MemorySource
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var imagePath: String? // Путь к фото на диске (опционально)
    var audioPath: String? // Путь к оригинальной голосовой записи на диске (опционально)

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        why: String = "",
        summary: String = "",
        source: MemorySource = .userCreated,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        imagePath: String? = nil,
        audioPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.why = why
        self.summary = summary
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.imagePath = imagePath
        self.audioPath = audioPath
    }
}
