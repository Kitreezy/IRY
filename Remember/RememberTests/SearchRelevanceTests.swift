import Testing
import Foundation
import GRDB
@testable import Remember

@Suite("Search relevance")
struct SearchRelevanceTests {

    /// Есть ли лемматизатор для русского. Проверяется делом: в симуляторе
    /// iOS его ресурсов нет, и слова остаются как написаны. Тесты, которым
    /// нужны именно леммы, там пропускаются.
    static let hasLemmas = SearchText.lemmas(of: "ключей") == ["ключ"]

    private func makeRepository(_ memories: [MemoryItem]) async throws -> GRDBMemoryRepository {
        let repo = GRDBMemoryRepository(writer: try AppDatabase(inMemory: true).writer)
        for memory in memories {
            try await repo.save(memory)
        }
        return repo
    }

    // MARK: - Запрос

    @Test("Query keeps meaningful words in both forms, joined by OR", .enabled(if: hasLemmas))
    func patternDropsStopWords() {
        #expect(SearchText.pattern(for: "где мои ключи от машины?")
                == "\"ключ\" OR \"ключи\" OR \"машина\" OR \"машины\"")
    }

    @Test("Without a lemmatizer words are searched as written")
    func patternWithoutLemmas() throws {
        let pattern = try #require(SearchText.pattern(for: "ключи от машины"))
        #expect(pattern.contains("\"ключи\"") && pattern.contains("\"машины\""))
        #expect(!pattern.contains("\"от\""))
    }

    @Test("Query of stop words only finds nothing")
    func patternOfStopWords() {
        #expect(SearchText.pattern(for: "где это?") == nil)
    }

    @Test("Short phrase is lemmatized too", .enabled(if: hasLemmas))
    func shortPhrase() {
        // Без явного языка лемматизатор оставлял «подарок дедушки» как есть.
        #expect(SearchText.lemmas(of: "подарок дедушки") == ["подарок", "дедушка"])
    }

    // MARK: - Полнотекстовый поиск

    @Test("Word in another form is found", .enabled(if: hasLemmas))
    func morphology() async throws {
        let memory = MemoryItem(title: "Запись", content: "Записалась к стоматологу на 14 ноября")
        let repo = try await makeRepository([memory])

        #expect(try await repo.search(query: "стоматолог").map(\.id) == [memory.id])
    }

    @Test("Natural question is found despite its stop words")
    func question() async throws {
        let memory = MemoryItem(title: "Вайфай на даче", content: "Пароль записан на роутере снизу")
        let repo = try await makeRepository([memory])

        #expect(try await repo.search(query: "какой пароль от вайфая на даче?").map(\.id) == [memory.id])
    }

    @Test("Why it matters is searchable")
    func whyIsIndexed() async throws {
        let memory = MemoryItem(title: "Часы", content: "Старые механические часы", why: "Дедушка подарил перед отъездом")
        let repo = try await makeRepository([memory])

        #expect(try await repo.search(query: "дедушка").map(\.id) == [memory.id])
    }

    @Test("More matching words rank higher than recency")
    func relevanceOverDate() async throws {
        let old = MemoryItem(title: "Ключи от машины", content: "Запасные ключи от машины в прихожей",
                             createdAt: Date(timeIntervalSince1970: 0))
        let recent = MemoryItem(title: "Машина", content: "Записался на мойку машины")
        let repo = try await makeRepository([old, recent])

        let results = try await repo.search(query: "ключи от машины")

        #expect(results.first?.id == old.id, "Совпали оба слова — выше, хотя старше")
    }

    @Test("Migration indexes memories saved before it")
    func migrationBackfills() throws {
        let queue = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        Migrations.register(in: &migrator)
        try migrator.migrate(queue, upTo: "v7_embedding_model")
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO memory_items (id, title, content, why, summary, source, created_at, updated_at, tags)
                VALUES (?, 'Запись', 'Записалась к стоматологу', '', '', 'userCreated', ?, ?, '')
                """, arguments: [UUID().uuidString, Date(), Date()])
        }

        try migrator.migrate(queue)

        // Строка, сохранённая до миграции, получила текст для поиска — тем же
        // путём, что новые, — и попала в пересозданный индекс.
        let (searchText, indexed) = try queue.read { db in
            (try String.fetchOne(db, sql: "SELECT search_text FROM memory_items"),
             try Int.fetchOne(db, sql: "SELECT count(*) FROM memory_items_fts"))
        }
        #expect(searchText == SearchText.index(title: "Запись", content: "Записалась к стоматологу", why: "", tags: []))
        #expect(searchText?.isEmpty == false)
        #expect(indexed == 1)
    }

    // MARK: - Слияние

    @Test("Found by both beats found by one")
    func fusionPrefersBoth() {
        let a = MemoryItem(title: "a", content: ""), b = MemoryItem(title: "b", content: ""), c = MemoryItem(title: "c", content: "")

        let fused = SemanticSearchService.fuse(fts: [a, b], semantic: [c.id, b.id], all: [a, b, c])

        #expect(fused.first?.id == b.id)
    }

    @Test("Ties are broken by full-text order, the same every time")
    func fusionTiesAreStable() {
        let a = MemoryItem(title: "a", content: ""), c = MemoryItem(title: "c", content: "")

        // Первое место в одном списке весит столько же, сколько в другом.
        for _ in 0..<20 {
            let fused = SemanticSearchService.fuse(fts: [a], semantic: [c.id], all: [a, c])
            #expect(fused.map(\.id) == [a.id, c.id])
        }
    }
}
