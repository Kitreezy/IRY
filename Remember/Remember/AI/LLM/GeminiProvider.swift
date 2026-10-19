import Foundation

// MARK: - Gemini Text Completion

actor GeminiTextCompletionProvider: TextCompletionProvider {
    let providerName = "Gemini"
    let isAvailable = true

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gemini-2.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }

    func complete(_ request: CompletionRequest) async throws -> String {
        try await complete(prompt: request.prompt)
    }

    func complete(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 300
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? -1

            guard statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                throw LLMError.httpError(statusCode, body)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let choices = json?["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            guard let text = message?["content"] as? String else {
                let raw = String(data: data, encoding: .utf8) ?? "empty"
                throw LLMError.parseError(raw)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
}

// MARK: - Gemini Embedding

actor GeminiEmbeddingProvider: EmbeddingProvider {
    let providerName = "Gemini gemini-embedding-001"
    let isAvailable = true

    /// Одна модель на все языки — поэтому русский запрос находит и
    /// английское воспоминание. На устройстве так не выйдет.
    static let model = "gemini.gemini-embedding-001"

    func model(for text: String) async -> String { Self.model }

    nonisolated func threshold(for model: String) -> Float { 0.55 }

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func embed(text: String) async throws -> TextEmbedding {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "models/gemini-embedding-001",
            "content": ["parts": [["text": text]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? -1

            guard statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                throw LLMError.httpError(statusCode, body)
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let embedding = json?["embedding"] as? [String: Any]
            guard let values = embedding?["values"] as? [Double] else {
                let raw = String(data: data, encoding: .utf8) ?? "empty"
                throw LLMError.parseError(raw)
            }
            return TextEmbedding(vector: values.map { Float($0) }, model: Self.model)
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
}
