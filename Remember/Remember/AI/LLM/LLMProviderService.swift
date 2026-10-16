import Foundation

/// Central service for AI provider selection.
/// Persists the user's choice and builds concrete providers on demand.
@Observable
final class LLMProviderService: @unchecked Sendable {
    static let shared = LLMProviderService()

    private(set) var currentKind: LLMProviderKind

    /// Кэш построенных провайдеров.
    ///
    /// Без кэша каждое обращение к `.embedding` создавало новый объект и читало
    /// ключ из Keychain. В параллельном цикле на 500 элементов это 500 обращений
    /// к Keychain — они сериализуются системой и съедают выигрыш от параллелизма.
    private let cacheLock = NSLock()
    private var cachedTextCompletion: (kind: LLMProviderKind, provider: any TextCompletionProvider)?
    private var cachedEmbedding: (kind: LLMProviderKind, provider: any EmbeddingProvider)?

    init() {
        let raw = UserDefaults.standard.string(forKey: "llm_provider") ?? LLMProviderKind.apple.rawValue
        self.currentKind = LLMProviderKind(rawValue: raw) ?? .apple
    }

    func select(_ kind: LLMProviderKind) {
        currentKind = kind
        UserDefaults.standard.set(kind.rawValue, forKey: "llm_provider")
        invalidateCache()
    }

    func saveAPIKey(_ key: String, for kind: LLMProviderKind) {
        APIKeyStore.save(key: key, for: kind)
        invalidateCache()
    }

    func apiKey(for kind: LLMProviderKind) -> String? {
        APIKeyStore.load(for: kind)
    }

    private func invalidateCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedTextCompletion = nil
        cachedEmbedding = nil
    }

    // MARK: - Build providers

    var textCompletion: any TextCompletionProvider {
        let kind = currentKind
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cachedTextCompletion, cached.kind == kind {
            return cached.provider
        }
        let provider = makeTextCompletion(kind)
        cachedTextCompletion = (kind, provider)
        return provider
    }

    var embedding: any EmbeddingProvider {
        let kind = currentKind
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cachedEmbedding, cached.kind == kind {
            return cached.provider
        }
        let provider = makeEmbedding(kind)
        cachedEmbedding = (kind, provider)
        return provider
    }

    // MARK: - Factories

    private func makeTextCompletion(_ kind: LLMProviderKind) -> any TextCompletionProvider {
        switch kind {
        case .apple:
            if #available(iOS 26.0, *) {
                return AppleTextCompletionProvider()
            }
            return UnavailableTextCompletionProvider()
        case .gemini:
            return GeminiTextCompletionProvider(apiKey: APIKeyStore.load(for: .gemini) ?? "")
        case .openAI:
            return OpenAITextCompletionProvider(apiKey: APIKeyStore.load(for: .openAI) ?? "")
        case .claude:
            return ClaudeTextCompletionProvider(apiKey: APIKeyStore.load(for: .claude) ?? "")
        }
    }

    private func makeEmbedding(_ kind: LLMProviderKind) -> any EmbeddingProvider {
        switch kind {
        case .apple:
            return AppleEmbeddingProvider()
        case .gemini:
            return GeminiEmbeddingProvider(apiKey: APIKeyStore.load(for: .gemini) ?? "")
        case .openAI:
            return OpenAIEmbeddingProvider(apiKey: APIKeyStore.load(for: .openAI) ?? "")
        case .claude:
            // Claude не предоставляет embeddings API — остаёмся на on-device.
            return AppleEmbeddingProvider()
        }
    }
}
