import AppIntents
import CoreLocation
import Foundation

/// Воспоминание — для Siri, Shortcuts и Apple Intelligence.
///
/// Объявлено по схеме записи журнала (`.journal.entry`): так система знает,
/// что это за вещь, без примеров фраз — «запиши в журнал», «найди запись»
/// Apple Intelligence сопоставит с ним сама. Свойства схемы — заголовок,
/// текст, дата, вложения, место; «почему это важно» в схеме нет, и оно —
/// собственное свойство сверх неё.
@AppEntity(schema: .journal.entry)
struct MemoryAppEntity {
    static let defaultQuery = MemoryEntityQuery()

    let id: UUID
    var title: String?
    var message: AttributedString?
    var mediaItems: [IntentFile]
    var entryDate: Date?
    var location: CLPlacemark?

    @Property(title: LocalizedStringResource("intent.entity.why"))
    var why: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title ?? "")",
            subtitle: why.isEmpty ? nil : "\(why)"
        )
    }

    init(_ memory: MemoryItem) {
        id = memory.id
        title = memory.title
        message = AttributedString(memory.content)
        // Фото — файлом: Shortcuts сможет отправить его дальше.
        mediaItems = memory.imagePath.map { [IntentFile(fileURL: URL(fileURLWithPath: $0))] } ?? []
        entryDate = memory.createdAt
        location = nil
        why = memory.why
    }
}

/// Как система достаёт воспоминания: по идентификатору, по тексту и
/// «что предложить», когда человек выбирает воспоминание в Shortcuts.
struct MemoryEntityQuery: EntityStringQuery {
    @Dependency private var service: MemoryIntentService

    func entities(for identifiers: [UUID]) async throws -> [MemoryAppEntity] {
        await service.memories(ids: identifiers).map(MemoryAppEntity.init)
    }

    func entities(matching string: String) async throws -> [MemoryAppEntity] {
        await service.search(string).map(MemoryAppEntity.init)
    }

    func suggestedEntities() async throws -> [MemoryAppEntity] {
        await service.recent().map(MemoryAppEntity.init)
    }
}
