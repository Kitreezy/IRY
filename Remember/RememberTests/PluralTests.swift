import Testing
import Foundation
@testable import Remember

/// Формы числа из Localizable.stringsdict. Раньше форма выбиралась как
/// `count == 1 ? one : other` — по-английски, — и выходило «21 воспоминаний».
@Suite("Plurals")
struct PluralTests {

    private func format(_ key: String, _ language: String, _ arguments: CVarArg...) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: Locale(identifier: language), arguments: arguments)
    }

    @Test("Russian has three forms, chosen by the last digits", arguments: [
        (1, "1 воспоминание"), (2, "2 воспоминания"), (5, "5 воспоминаний"),
        (11, "11 воспоминаний"), (21, "21 воспоминание"), (22, "22 воспоминания")
    ])
    func russian(count: Int, expected: String) throws {
        #expect(try format("people.mentions", "ru", count) == expected)
    }

    @Test("English has two")
    func english() throws {
        #expect(try format("people.mentions", "en", 1) == "1 memory")
        #expect(try format("people.mentions", "en", 21) == "21 memories")
    }

    @Test("Word under the count agrees with it")
    func label() throws {
        #expect(try format("home.memories.label", "ru", 1) == "воспоминание")
        #expect(try format("home.memories.label", "ru", 3) == "воспоминания")
        #expect(try format("home.memories.label", "ru", 25) == "воспоминаний")
    }

    @Test("Import result keeps the source name")
    func importResult() throws {
        #expect(try format("settings.import.result", "ru", 3, "Календаря") == "Импортировано: 3 воспоминания из Календаря")
    }
}
