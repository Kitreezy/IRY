import Foundation

/// То, что приложение умеет делать по просьбе Siri, Shortcuts и Apple
/// Intelligence: запомнить, найти, ответить, достать по идентификатору.
///
/// Логика — здесь, а не в интентах. Интент — это описание для системы:
/// параметры, фразы, схема; проверять его можно только через Siri. Сервис
/// же проверяется тестом, как всё остальное в приложении. Сохраняет и ищет
/// он теми же путями, что и экраны, — иначе запомненное голосом не нашлось
/// бы поиском.
actor MemoryIntentService {
    private let repository: any MemoryRepository
    private let semantic: SemanticSearchService
    private let answers: any AnswerProviding

    init(repository: any MemoryRepository,
         semantic: SemanticSearchService? = nil,
         answers: any AnswerProviding = AnswerServiceFactory.make()) {
        self.repository = repository
        self.semantic = semantic ?? SemanticSearchService(repository: repository)
        self.answers = answers
    }

    /// Запомнить. Без заголовка — первые слова текста, как при голосовой записи.
    func remember(text: String, title: String? = nil, why: String = "", date: Date? = nil) async throws -> MemoryItem {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = MemoryItem(
            title: heading?.isEmpty == false ? heading! : Self.title(from: content),
            content: content,
            why: why.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: date ?? Date(),
            updatedAt: Date()
        )
        try await repository.save(memory)
        // Вектор — сразу: иначе воспоминание найдётся по смыслу только после
        // следующего запуска, когда фоновая индексация его подберёт.
        await semantic.indexMemory(memory)
        return memory
    }

    /// Найти — тем же гибридным поиском, что и строка поиска на главном экране.
    func search(_ query: String, limit: Int = 10) async -> [MemoryItem] {
        let fts = (try? await repository.search(query: query)) ?? []
        return Array(await semantic.search(query: query, ftsResults: fts).prefix(limit))
    }

    /// Ответить на вопрос по воспоминаниям. Ответа может не быть — модели нет
    /// или в воспоминаниях нечего сказать; найденное возвращается всё равно.
    func answer(_ question: String) async -> (answer: String?, memories: [MemoryItem]) {
        let found = await search(question, limit: 5)
        guard !found.isEmpty, answers.isAvailable else {
            return (nil, found)
        }
        return (await answers.answer(question: question, memories: found), found)
    }

    func memories(ids: [UUID]) async -> [MemoryItem] {
        var result: [MemoryItem] = []
        for id in ids {
            if let memory = try? await repository.fetch(id: id) {
                result.append(memory)
            }
        }
        return result
    }

    /// Что предложить, когда человек выбирает воспоминание в Shortcuts, — свежее.
    func recent(limit: Int = 10) async -> [MemoryItem] {
        Array(((try? await repository.fetchAll()) ?? []).prefix(limit))
    }

    static func title(from text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace).prefix(6).joined(separator: " ")
        return words.count < text.count ? words + "…" : words
    }
}
