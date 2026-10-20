import AppIntents
import CoreLocation
import Foundation

/// «Запомни…» — по схеме создания записи журнала.
@AppIntent(schema: .journal.createEntry)
struct CreateMemoryIntent {
    var message: AttributedString
    var title: String?
    var entryDate: Date?
    var location: CLPlacemark?
    var mediaItems: [IntentFile]

    @Dependency private var service: MemoryIntentService

    func perform() async throws -> some ReturnsValue<MemoryAppEntity> & ProvidesDialog {
        let memory = try await service.remember(text: String(message.characters), title: title, date: entryDate)
        return .result(value: MemoryAppEntity(memory),
                       dialog: IntentDialog(LocalizedStringResource("intent.create.done \(memory.title)")))
    }
}

/// «Найди в Remember…» — системный поиск: открывает поиск приложения с запросом.
@AppIntent(schema: .system.search)
struct SearchMemoriesIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.open(.search(criteria.term))
        return .result()
    }
}

/// «Что я знаю о…» — ответ по воспоминаниям, там, где спросили: в Siri, в
/// Shortcuts. Найденное возвращается значением, и Shortcuts может передать
/// его дальше — например, в действие модели Apple Intelligence.
struct AskMemoriesIntent: AppIntent {
    static let title = LocalizedStringResource("intent.ask.title")
    static let description = IntentDescription(LocalizedStringResource("intent.ask.description"))

    @Parameter(title: LocalizedStringResource("intent.ask.question"))
    var question: String

    @Dependency private var service: MemoryIntentService

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$question)")
    }

    func perform() async throws -> some ReturnsValue<[MemoryAppEntity]> & ProvidesDialog {
        let (answer, memories) = await service.answer(question)
        let dialog: IntentDialog
        if let answer, !answer.isEmpty {
            dialog = IntentDialog(stringLiteral: answer)
        } else if memories.isEmpty {
            dialog = IntentDialog(LocalizedStringResource("intent.ask.nothing"))
        } else {
            // Ответа нет — модели нет или она не нашла, что сказать, — но
            // найденное есть: лучше назвать его, чем промолчать.
            dialog = IntentDialog(LocalizedStringResource("intent.ask.found \(memories.count)"))
        }
        return .result(value: memories.map(MemoryAppEntity.init), dialog: dialog)
    }
}

/// Открыть воспоминание — из Shortcuts, из ответа Siri, из Spotlight.
struct OpenMemoryIntent: OpenIntent {
    static let title = LocalizedStringResource("intent.open.title")

    @Parameter(title: LocalizedStringResource("intent.open.memory"))
    var target: MemoryAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.open(.memory(target.id))
        return .result()
    }
}
