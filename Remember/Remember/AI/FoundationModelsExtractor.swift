import Foundation
import FoundationModels

// MARK: - Generable output

@available(iOS 26.0, *)
@Generable
struct ExtractedEntities {
    @Guide(description: "Full names of people mentioned in the text. Empty array if none.")
    var people: [String]

    @Guide(description: "Cities, countries, or locations mentioned. Empty array if none.")
    var places: [String]

    @Guide(description: "Main topics, concepts, or subjects discussed. Empty array if none.")
    var topics: [String]

    @Guide(description: "Company or organization names mentioned. Empty array if none.")
    var companies: [String]
}

// MARK: - Extractor

@available(iOS 26.0, *)
actor FoundationModelsExtractor: EntityExtracting {
    private let bridge: any LanguageBridge

    init(bridge: any LanguageBridge = OnDeviceLanguageBridge()) {
        self.bridge = bridge
    }

    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Русский текст модель не знает — он идёт через перевод, а найденное
    /// переводится обратно. Обратный перевод заодно ставит названия в
    /// начальную форму: «в Казани» → «in Kazan» → «Казань», и одно место в
    /// разных воспоминаниях совпадает, хотя стояло в разных падежах.
    func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity] {
        var types: [EntityType] = []
        let values = try await bridge.bridged([text]) { input in
            let session = LanguageModelSession(
                model: .default,
                instructions: "Extract named entities from the user's text. Return only entities explicitly mentioned."
            )
            let response = try await session.respond(to: input.joined(), generating: ExtractedEntities.self)
            let extracted = response.content
            let found: [(EntityType, [String])] = [
                (.person, extracted.people), (.place, extracted.places),
                (.topic, extracted.topics), (.company, extracted.companies)
            ]
            // Значения — плоским списком, чтобы перевести их одной пачкой;
            // тип каждого запоминается по порядку.
            types = found.flatMap { type, names in names.filter { !$0.isEmpty }.map { _ in type } }
            return found.flatMap { _, names in names.filter { !$0.isEmpty } }
        }
        return Self.entities(values: values, types: types, memoryId: memoryId)
    }

    /// Значения и типы — обратно в сущности. Пустое после перевода и
    /// повторы одного типа отбрасываются.
    static func entities(values: [String], types: [EntityType], memoryId: UUID) -> [MemoryEntity] {
        var seen = Set<String>()
        return zip(values, types).compactMap { value, type in
            let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert("\(type.rawValue)|\(value.lowercased())").inserted else {
                return nil
            }
            return MemoryEntity(memoryId: memoryId, value: value, type: type)
        }
    }
}

// MARK: - Fallback for iOS < 26

struct UnavailableEntityExtractor: EntityExtracting {
    nonisolated var isAvailable: Bool { false }
    func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity] { [] }
}
