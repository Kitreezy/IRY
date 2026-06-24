import Foundation

#if DEBUG
enum SeedData {
    static let memories: [MemoryItem] = [
        MemoryItem(
            title: "AI CRM идея",
            content: "Обсуждали с Сергеем идею AI-powered CRM для продажников. Основная проблема — монетизация и конкуренция с Salesforce.",
            source: .userCreated,
            createdAt: Date().addingTimeInterval(-86400 * 30),
            tags: ["AI", "startup", "CRM"]
        ),
        MemoryItem(
            title: "Поездка в Лондон",
            content: "Планируем поездку в Лондон в сентябре. Нужно забронировать отель рядом с Shoreditch. Посмотреть Tate Modern и Borough Market.",
            source: .calendar,
            createdAt: Date().addingTimeInterval(-86400 * 14),
            tags: ["travel", "London"]
        ),
        MemoryItem(
            title: "Встреча с инвестором",
            content: "Встреча с Михаилом из Flint Capital. Он заинтересован в B2B SaaS с ARR от $500k. Следующий шаг — отправить deck до пятницы.",
            source: .appleNotes,
            createdAt: Date().addingTimeInterval(-86400 * 7),
            tags: ["investor", "fundraising"]
        ),
        MemoryItem(
            title: "Книга: Thinking Fast and Slow",
            content: "Система 1 и Система 2. Быстрое мышление — интуиция. Медленное — логика. Anchoring effect влияет на все переговоры.",
            source: .userCreated,
            createdAt: Date().addingTimeInterval(-86400 * 21),
            tags: ["book", "psychology"]
        ),
        MemoryItem(
            title: "Remember — архитектура",
            content: "Feature-first модульная архитектура. Domain слой чистый без зависимостей. Storage через GRDB с FTS5. AI через Apple Foundation Models.",
            source: .appleNotes,
            createdAt: Date().addingTimeInterval(-86400 * 3),
            tags: ["IRY", "architecture", "iOS"]
        ),
        MemoryItem(
            title: "Идея: Memory Graph",
            content: "Граф связей между людьми, событиями и темами. Автоматически строится из контента. Позволяет находить неочевидные связи.",
            source: .userCreated,
            createdAt: Date().addingTimeInterval(-86400 * 5),
            tags: ["IRY", "product"]
        ),
        MemoryItem(
            title: "Разговор с Антоном про ценообразование",
            content: "Антон считает что freemium убьёт продукт. Лучше $9.99/месяц с 14-дневным триалом. Смотреть на Reeder и Bear как бенчмарк.",
            source: .userCreated,
            createdAt: Date().addingTimeInterval(-86400 * 10),
            tags: ["pricing", "strategy"]
        ),
        MemoryItem(
            title: "Swift Concurrency заметки",
            content: "Actor isolation решает data races. @MainActor для UI. Sendable протокол для thread-safe типов. Task.sleep вместо DispatchQueue.asyncAfter.",
            source: .appleNotes,
            createdAt: Date().addingTimeInterval(-86400 * 2),
            tags: ["swift", "concurrency", "iOS"]
        ),
    ]
}
#endif
