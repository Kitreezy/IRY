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
    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity] {
        let session = LanguageModelSession(model: .default)
        let prompt = """
            Extract named entities from the following text.
            Return only entities explicitly mentioned.

            Text: \(text)
            """

        let response = try await session.respond(
            to: prompt,
            generating: ExtractedEntities.self
        )

        let extracted = response.content
        var entities: [MemoryEntity] = []

        for name in extracted.people where !name.isEmpty {
            entities.append(MemoryEntity(memoryId: memoryId, value: name, type: .person))
        }
        for place in extracted.places where !place.isEmpty {
            entities.append(MemoryEntity(memoryId: memoryId, value: place, type: .place))
        }
        for topic in extracted.topics where !topic.isEmpty {
            entities.append(MemoryEntity(memoryId: memoryId, value: topic, type: .topic))
        }
        for company in extracted.companies where !company.isEmpty {
            entities.append(MemoryEntity(memoryId: memoryId, value: company, type: .company))
        }

        return entities
    }
}

// MARK: - Fallback for iOS < 26

struct UnavailableEntityExtractor: EntityExtracting {
    nonisolated var isAvailable: Bool { false }
    func extract(from text: String, memoryId: UUID) async throws -> [MemoryEntity] { [] }
}
