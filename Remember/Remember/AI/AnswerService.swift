import Foundation

// MARK: - Protocol

protocol AnswerProviding: Sendable {
    var isAvailable: Bool { get }
    func answer(question: String, memories: [MemoryItem]) async -> String?
}

// MARK: - Implementation

actor MemoryAnswerService: AnswerProviding {
    private let providerService: LLMProviderService

    init(providerService: LLMProviderService = .shared) {
        self.providerService = providerService
    }

    nonisolated var isAvailable: Bool {
        providerService.textCompletion.isAvailable
    }

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

        return try? await providerService.textCompletion.complete(prompt: prompt)
    }
}

// MARK: - Fallback

struct UnavailableAnswerService: AnswerProviding {
    let isAvailable = false
    func answer(question: String, memories: [MemoryItem]) async -> String? { nil }
}

// MARK: - Factory

enum AnswerServiceFactory {
    static func make(providerService: LLMProviderService = .shared) -> any AnswerProviding {
        MemoryAnswerService(providerService: providerService)
    }
}
