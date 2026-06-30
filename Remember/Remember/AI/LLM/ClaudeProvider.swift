import Foundation

// MARK: - Claude Text Completion

actor ClaudeTextCompletionProvider: TextCompletionProvider {
    let providerName = "Claude"
    let isAvailable = true

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "claude-haiku-4-5-20251001") {
        self.apiKey = apiKey
        self.model = model
    }

    func complete(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.noAPIKey }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw LLMError.invalidResponse
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let content = json?["content"] as? [[String: Any]]
            guard let text = content?.first?["text"] as? String else {
                throw LLMError.invalidResponse
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LLMError {
            throw error
        } catch {
            throw LLMError.networkError(error)
        }
    }
}
