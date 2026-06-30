import Foundation

/// Central service for AI provider selection.
/// Persists the user's choice and builds concrete providers on demand.
@Observable
final class LLMProviderService: @unchecked Sendable {
    static let shared = LLMProviderService()

    private(set) var currentKind: LLMProviderKind

    init() {
        let raw = UserDefaults.standard.string(forKey: "llm_provider") ?? LLMProviderKind.apple.rawValue
        self.currentKind = LLMProviderKind(rawValue: raw) ?? .apple
    }

    func select(_ kind: LLMProviderKind) {
        currentKind = kind
        UserDefaults.standard.set(kind.rawValue, forKey: "llm_provider")
    }

    func saveAPIKey(_ key: String, for kind: LLMProviderKind) {
        APIKeyStore.save(key: key, for: kind)
    }

    func apiKey(for kind: LLMProviderKind) -> String? {
        APIKeyStore.load(for: kind)
    }

    // MARK: - Build providers

    var textCompletion: any TextCompletionProvider {
        switch currentKind {
        case .apple:
            if #available(iOS 26.0, *) {
                return AppleTextCompletionProvider()
            }
            return UnavailableTextCompletionProvider()
        case .gemini:
            let key = APIKeyStore.load(for: .gemini) ?? ""
            return GeminiTextCompletionProvider(apiKey: key)
        // TODO: re-enable when OpenAI credits available
        case .openAI:
            let key = APIKeyStore.load(for: .openAI) ?? ""
            return OpenAITextCompletionProvider(apiKey: key)
        // TODO: re-enable when Claude API key available
        case .claude:
            let key = APIKeyStore.load(for: .claude) ?? ""
            return ClaudeTextCompletionProvider(apiKey: key)
        }
    }

    var embedding: any EmbeddingProvider {
        switch currentKind {
        case .apple:
            return AppleEmbeddingProvider()
        case .gemini:
            let key = APIKeyStore.load(for: .gemini) ?? ""
            return GeminiEmbeddingProvider(apiKey: key)
        // TODO: re-enable when OpenAI credits available
        case .openAI:
            let key = APIKeyStore.load(for: .openAI) ?? ""
            return OpenAIEmbeddingProvider(apiKey: key)
        // TODO: re-enable when Claude API key available
        case .claude:
            return AppleEmbeddingProvider()
        }
    }
}
