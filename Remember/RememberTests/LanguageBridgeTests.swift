import Testing
import Foundation
@testable import Remember

/// Мост по сценарию: маршрут задан, перевод помечает строку языком
/// назначения — «привет» → «[en] привет». Так видно, что и куда ушло.
private final class StubBridge: LanguageBridge, @unchecked Sendable {
    let routeToReturn: BridgeRoute
    private(set) var translations: [(source: String, target: String, texts: [String])] = []

    init(_ route: BridgeRoute) {
        self.routeToReturn = route
    }

    func route(for texts: [String]) async -> BridgeRoute { routeToReturn }

    func translate(_ texts: [String], from source: Locale.Language, to target: Locale.Language) async throws -> [String] {
        translations.append((source.minimalIdentifier, target.minimalIdentifier, texts))
        return texts.map { "[\(target.minimalIdentifier)] \($0)" }
    }
}

@Suite("Language bridge")
struct LanguageBridgeTests {

    private let russian = Locale.Language(identifier: "ru")

    @Test("Known language goes straight to the model")
    func direct() async throws {
        let bridge = StubBridge(.direct)
        var seen: [String] = []

        let result = try await bridge.bridged(["hello"]) { input in
            seen = input
            return ["answer"]
        }

        #expect(seen == ["hello"])
        #expect(result == ["answer"])
        #expect(bridge.translations.isEmpty)
    }

    @Test("Unknown language goes there and back")
    func translated() async throws {
        let bridge = StubBridge(.translate(russian))
        var seen: [String] = []

        let result = try await bridge.bridged(["где ключи", "ключи в прихожей"]) { input in
            seen = input
            return ["in the hallway"]
        }

        #expect(seen == ["[en] где ключи", "[en] ключи в прихожей"], "Модель видит переведённое")
        #expect(result == ["[ru] in the hallway"], "Человек получает ответ на своём языке")
        #expect(bridge.translations.map(\.texts.count) == [2, 1], "Туда и обратно — по одной пачке")
    }

    @Test("Missing languages are reported without calling the model")
    func needsDownload() async {
        let bridge = StubBridge(.needsDownload(russian))
        var called = false

        await #expect(throws: LLMError.self) {
            _ = try await bridge.bridged(["где ключи"]) { _ in
                called = true
                return []
            }
        }
        #expect(!called)
    }

    @Test("Unsupported language is reported without calling the model")
    func unsupported() async {
        let bridge = StubBridge(.unsupported(Locale.Language(identifier: "xx")))
        var called = false

        await #expect(throws: LLMError.self) {
            _ = try await bridge.bridged(["?"]) { _ in
                called = true
                return []
            }
        }
        #expect(!called)
    }

    @Test("Cloud providers get instructions and data as one prompt")
    func promptJoinsParts() {
        let request = CompletionRequest(instructions: "Answer briefly.", content: ["Question: где ключи", "Memory: в прихожей"])

        #expect(request.prompt == "Answer briefly.\n\nQuestion: где ключи\n\nMemory: в прихожей")
    }

    @Test("Translated entity names keep their types and drop repeats")
    func entitiesAfterTranslation() throws {
        guard #available(iOS 26.0, *) else { return }
        let id = UUID()

        // Обратный перевод ставит в начальную форму: «в Казани» и «Казань»
        // приходят одним значением, и повтор отбрасывается.
        let entities = FoundationModelsExtractor.entities(
            values: ["Анна", "Казань", "казань", " ", "Яндекс"],
            types: [.person, .place, .place, .topic, .company],
            memoryId: id
        )

        #expect(entities.map(\.value) == ["Анна", "Казань", "Яндекс"])
        #expect(entities.map(\.type) == [.person, .place, .company])
        #expect(entities.allSatisfy { $0.memoryId == id })
    }
}
