import Foundation
import FoundationModels

// MARK: - Apple Text Completion (iOS 26+)

@available(iOS 26.0, *)
actor AppleTextCompletionProvider: TextCompletionProvider {
    let providerName = "Apple Foundation Models"

    private let bridge: any LanguageBridge

    init(bridge: any LanguageBridge = OnDeviceLanguageBridge()) {
        self.bridge = bridge
    }

    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Языка данных модель не знает — данные идут через перевод, ответ
    /// возвращается на языке данных. Инструкция не переводится: она и так
    /// по-английски.
    func complete(_ request: CompletionRequest) async throws -> String {
        guard isAvailable else { throw LLMError.notAvailable }
        let answer = try await bridge.bridged(request.content) { content in
            // Инструкция — отдельно от данных: модель следует ей и не
            // принимает за инструкцию то, что написано в воспоминании.
            let session = LanguageModelSession(model: .default, instructions: request.instructions)
            let response = try await session.respond(to: content.joined(separator: "\n\n"))
            return [response.content]
        }
        return (answer.first ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Fallbacks

struct UnavailableTextCompletionProvider: TextCompletionProvider {
    let providerName = "Unavailable"
    let isAvailable = false
    func complete(_ request: CompletionRequest) async throws -> String { throw LLMError.notAvailable }
}
