import Testing
import Foundation
@testable import Remember

/// Ответчик по сценарию: модель есть или нет, ответ задан.
private struct StubAnswers: AnswerProviding {
    var isAvailable = true
    var reply: String? = "ответ"
    func answer(question: String, memories: [MemoryItem]) async -> String? { reply }
}

@Suite("App Intents — service")
struct MemoryIntentServiceTests {

    private func makeService(answers: any AnswerProviding = StubAnswers()) throws -> (GRDBMemoryRepository, MemoryIntentService) {
        let repo = GRDBMemoryRepository(writer: try AppDatabase(inMemory: true).writer)
        return (repo, MemoryIntentService(repository: repo, answers: answers))
    }

    @Test("Remembered by voice is saved like any memory")
    func rememberSaves() async throws {
        let (repo, service) = try makeService()

        let memory = try await service.remember(text: "  Ключи в ящике комода  ", title: "Ключи", why: " на всякий случай ")

        let saved = try #require(try await repo.fetch(id: memory.id))
        #expect(saved.title == "Ключи")
        #expect(saved.content == "Ключи в ящике комода")
        #expect(saved.why == "на всякий случай")
    }

    @Test("Without a title the first words become one")
    func titleFromText() async throws {
        let (_, service) = try makeService()

        let long = try await service.remember(text: "Запасные ключи от машины лежат в ящике комода в прихожей")
        let short = try await service.remember(text: "Позвонить маме")

        #expect(long.title == "Запасные ключи от машины лежат в…")
        #expect(short.title == "Позвонить маме")
    }

    @Test("Date from Siri is kept")
    func dateKept() async throws {
        let (_, service) = try makeService()
        let date = Date(timeIntervalSince1970: 1_000_000)

        let memory = try await service.remember(text: "Выпускной", date: date)

        #expect(memory.createdAt == date)
    }

    @Test("Remembered by voice is found by search")
    func rememberedIsFound() async throws {
        let (_, service) = try makeService()
        let memory = try await service.remember(text: "Пароль от вайфая на роутере снизу")

        #expect(await service.search("пароль").map(\.id).contains(memory.id))
    }

    @Test("Answer comes with what it was found in")
    func answerWithMemories() async throws {
        let (_, service) = try makeService(answers: StubAnswers(reply: "В ящике комода"))
        _ = try await service.remember(text: "Ключи в ящике комода")

        let (answer, memories) = await service.answer("ключи")

        #expect(answer == "В ящике комода")
        #expect(memories.count == 1)
    }

    @Test("Without a model the found memories still come back")
    func noModelStillFinds() async throws {
        let (_, service) = try makeService(answers: StubAnswers(isAvailable: false))
        _ = try await service.remember(text: "Ключи в ящике комода")

        let (answer, memories) = await service.answer("ключи")

        #expect(answer == nil)
        #expect(memories.count == 1, "Ответа нет, а найденное есть — его и показываем")
    }

    @Test("Entity carries the memory, why included")
    func entityMapping() throws {
        let memory = MemoryItem(title: "Часы", content: "Старые часы", why: "Подарок дедушки",
                                createdAt: Date(timeIntervalSince1970: 0))

        let entity = MemoryAppEntity(memory)

        #expect(entity.id == memory.id)
        #expect(entity.title == "Часы")
        #expect(entity.message.map { String($0.characters) } == "Старые часы")
        #expect(entity.why == "Подарок дедушки")
        #expect(entity.entryDate == memory.createdAt)
        #expect(entity.mediaItems.isEmpty)
    }
}

@Suite("App Intents — router")
@MainActor
struct AppRouterTests {

    @Test("A route is followed once")
    func takeOnce() {
        let router = AppRouter()
        router.open(.search("ключи"))

        #expect(router.take() == .search("ключи"))
        #expect(router.take() == nil, "Второй раз тот же экран не открывается")
    }
}

/// Контракт с системой: что Siri и Shortcuts увидят в приложении. Метаданные
/// извлекает Xcode при сборке из кода интентов — тест читает их из собранного
/// приложения, так что проверяет то, что поедет к пользователю.
@Suite("App Intents — metadata")
struct AppIntentsMetadataTests {

    private func metadata() throws -> [String: Any] {
        let url = try #require(Bundle.main.url(forResource: "extract", withExtension: "actionsdata",
                                               subdirectory: "Metadata.appintents"))
        return try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func schema(of action: [String: Any]?) -> String? {
        (action?["assistantDefinedSchemas"] as? [[String: Any]])?.first.map { "\($0["domain"]!).\($0["name"]!)" }
    }

    @Test("Actions are declared by the system schemas")
    func schemas() throws {
        let actions = try #require(try metadata()["actions"] as? [String: [String: Any]])

        #expect(schema(of: actions["CreateMemoryIntent"]) == "journal.CreateJournalEntryIntent")
        #expect(schema(of: actions["SearchMemoriesIntent"]) == "system.ShowInAppSearchResultsIntent")
        #expect(actions["AskMemoriesIntent"] != nil)
        #expect(actions["OpenMemoryIntent"] != nil)
    }

    @Test("Every Siri phrase has a Russian translation")
    func phrasesTranslated() throws {
        let shortcuts = try #require(try metadata()["autoShortcuts"] as? [[String: Any]])
        let phrases = shortcuts.flatMap { ($0["phraseTemplates"] as? [[String: Any]] ?? []).compactMap { $0["key"] as? String } }
        let path = try #require(Bundle.main.path(forResource: "AppShortcuts", ofType: "strings", inDirectory: nil, forLocalization: "ru"))
        let russian = try #require(NSDictionary(contentsOfFile: path) as? [String: String])

        #expect(!phrases.isEmpty)
        for phrase in phrases {
            #expect(russian[phrase] != nil, "Нет перевода фразы «\(phrase)»")
            #expect(russian[phrase]?.contains("${applicationName}") == true, "Siri узнаёт фразу только с именем приложения")
        }
    }
}
