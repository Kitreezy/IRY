import AppIntents

/// Фразы, по которым Siri находит действия приложения без настройки, и
/// плитки в Shortcuts и Spotlight.
///
/// Текст в фразу не подставить — только сущность или перечисление, — поэтому
/// «Запомни в Remember» без продолжения: что запомнить, Siri спросит сама.
/// Перевод фраз — в AppShortcuts.strings: у Siri отдельная таблица, и в
/// ней ключ — сама английская фраза.
struct RememberShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateMemoryIntent(),
            phrases: [
                "Remember in \(.applicationName)",
                "Add a memory to \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("shortcut.remember"),
            systemImageName: "plus.bubble"
        )
        AppShortcut(
            intent: AskMemoriesIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "What do I know in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("shortcut.ask"),
            systemImageName: "questionmark.bubble"
        )
        AppShortcut(
            intent: SearchMemoriesIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("shortcut.search"),
            systemImageName: "magnifyingglass"
        )
    }
}
