import Foundation

// MARK: - OpenAI Text Completion

actor OpenAITextCompletionProvider: TextCompletionProvider {
    let providerName = "OpenAI"
    let isAvailable = true

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.model = model
    }

    func complete(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 300,
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - OpenAI Embedding

actor OpenAIEmbeddingProvider: EmbeddingProvider {
    let providerName = "OpenAI text-embedding-3-small"
    let dimensions = 1536
    let isAvailable = true

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func embed(text: String) async throws -> [Float] {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "text-embedding-3-small",
            "input": text
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw LLMError.invalidResponse
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let embedData = (json?["data"] as? [[String: Any]])?.first
            guard let vector = embedData?["embedding"] as? [Double] else {
                throw LLMError.invalidResponse
            }
            return vector.map { Float($0) }
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
}
