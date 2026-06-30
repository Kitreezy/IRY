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
    case gemini = "gemini"
    // TODO: re-enable when OpenAI credits available
    case openAI = "openai"
    // TODO: re-enable when Claude API key available
    case claude = "claude"

    var displayName: String {
        switch self {
        case .apple: "Apple (on-device)"
        case .gemini: "Gemini"
        case .openAI: "OpenAI"
        case .claude: "Claude"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .apple: false
        case .gemini: true
        case .openAI: true
        case .claude: true
        }
    }

    var privacyNote: String {
        switch self {
        case .apple:
            "All processing happens on your device. Nothing leaves your phone."
        case .gemini:
            "Text is sent to Google Gemini servers. Excellent Russian support. See ai.google.dev/gemini-api/terms."
        case .openAI:
            "Text is sent to OpenAI servers. See openai.com/privacy."
        case .claude:
            "Text is sent to Anthropic servers. Embeddings stay on-device. See anthropic.com/privacy."
        }
    }
}

// MARK: - Errors

enum LLMError: Error, LocalizedError {
    case notAvailable
    case noAPIKey
    case networkError(Error)
    case invalidResponse
    case httpError(Int, String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: "AI provider is not available on this device."
        case .noAPIKey: "API key is required. Add it in Settings."
        case .networkError(let e): "Network error: \(e.localizedDescription)"
        case .invalidResponse: "Unexpected response from AI provider."
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        case .parseError(let raw): "Parse error. Response: \(raw)"
        }
    }
}
