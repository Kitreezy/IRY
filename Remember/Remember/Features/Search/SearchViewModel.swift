import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    var results: [MemoryItem] = []
    var answer: String? = nil
    var isLoading: Bool = false
    var isAnswering: Bool = false
    var error: String? = nil

    private let repository: any MemoryRepository
    private let semantic: SemanticSearchService
    private let answerService: any AnswerProviding
    private var searchTask: Task<Void, Never>?

    init(repository: any MemoryRepository) {
        self.repository = repository
        self.semantic = SemanticSearchService(repository: repository)
        self.answerService = AnswerServiceFactory.make()
    }

    func onQueryChanged() {
        searchTask?.cancel()
        answer = nil
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    func performSearch() async {
        isLoading = true
        answer = nil
        error = nil
        do {
            let ftsResults = try await repository.search(query: query)
            results = await semantic.search(query: query, ftsResults: ftsResults)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false

        // Generate answer if query looks like a question and we have results
        if !results.isEmpty && isQuestion(query) && answerService.isAvailable {
            await generateAnswer()
        }
    }

    func saveMemory(_ memory: MemoryItem) async {
        try? await repository.save(memory)
        await semantic.indexMemory(memory)
        await performSearch()
    }

    // MARK: - Private

    private func generateAnswer() async {
        isAnswering = true
        answer = await answerService.answer(question: query, memories: results)
        isAnswering = false
    }

    private func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count > 4 else { return false }
        let questionWords = ["когда", "что", "где", "кто", "как", "почему", "зачем",
                             "when", "what", "where", "who", "how", "why", "which"]
        return questionWords.contains(where: { trimmed.hasPrefix($0) }) || trimmed.hasSuffix("?")
    }
}
