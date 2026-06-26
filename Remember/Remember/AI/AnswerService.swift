import Foundation
import FoundationModels

// MARK: - Protocol

protocol AnswerProviding: Sendable {
    var isAvailable: Bool { get }
    func answer(question: String, memories: [MemoryItem]) async -> String?
}

// MARK: - Foundation Models implementation (iOS 26+)

@available(iOS 26.0, *)
actor FoundationModelsAnswerService: AnswerProviding {
    nonisolated let isAvailable: Bool = true

    func answer(question: String, memories: [MemoryItem]) async -> String? {
        guard !memories.isEmpty else { return nil }

        let context = memories.prefix(5).map { memory -> String in
            var parts = ["Memory: \(memory.title)"]
            if !memory.why.isEmpty { parts.append("Why it matters: \(memory.why)") }
            if !memory.content.isEmpty { parts.append("Content: \(memory.content)") }
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n---\n\n")

        let prompt = """
        The user asked: "\(question)"

        Based only on the following memories, give a short, direct answer.
        If the memories don't contain enough information, say so briefly.
        Do not invent information. Be concise — 1-3 sentences.

        \(context)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

// MARK: - Fallback (iOS < 26)

struct UnavailableAnswerService: AnswerProviding {
    let isAvailable: Bool = false
    func answer(question: String, memories: [MemoryItem]) async -> String? { nil }
}

// MARK: - Factory

enum AnswerServiceFactory {
    static func make() -> any AnswerProviding {
        if #available(iOS 26.0, *) {
            return FoundationModelsAnswerService()
        }
        return UnavailableAnswerService()
    }
}
