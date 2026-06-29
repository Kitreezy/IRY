import Foundation

// MARK: - Text Completion

protocol TextCompletionProvider: Sendable {
    var providerName: String { get }
    var isAvailable: Bool { get }
    func complete(prompt: String) async throws -> String
}

// MARK: - Embedding

protocol EmbeddingProvider: Sendable {
    var providerName: String { get }
    var dimensions: Int { get }
    var isAvailable: Bool { get }
    func embed(text: String) async throws -> [Float]
    func similarity(between a: [Float], and b: [Float]) -> Float
}

extension EmbeddingProvider {
    func similarity(between a: [Float], and b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(Float(0)) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(Float(0)) { $0 + $1 * $1 })
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }
}

// MARK: - Provider Kind

enum LLMProviderKind: String, CaseIterable, Sendable {
    case apple = "apple"
    case openAI = "openai"

    var displayName: String {
        switch self {
        case .apple: "Apple (on-device)"
        case .openAI: "OpenAI"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple: false
        case .openAI: true
        }
    }

    var privacyNote: String {
        switch self {
        case .apple:
            "All processing happens on your device. Nothing leaves your phone."
        case .openAI:
            "Text is sent to OpenAI servers. See openai.com/privacy."
        }
    }
}

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case notAvailable
    case noAPIKey
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAvailable: "AI provider is not available on this device."
        case .noAPIKey: "API key is required. Add it in Settings."
        case .networkError(let e): "Network error: \(e.localizedDescription)"
        case .invalidResponse: "Unexpected response from AI provider."
        }
    }
}
