import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    // MARK: - State

    var query = ""
    var results: [MemoryItem] = []
    var allMemories: [MemoryItem] = []
    var isSearching = false
    var isAnswering = false
    var answer: String?

    var memoriesCount: Int { allMemories.count }
    var isQueryActive: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: - Dependencies

    private let repository: any MemoryRepository
    private let semantic: SemanticSearchService
    private let answerService: any AnswerProviding
    private var searchTask: Task<Void, Never>?

    init(repository: any MemoryRepository) {
        self.repository = repository
        self.semantic = SemanticSearchService(repository: repository)
        self.answerService = AnswerServiceFactory.make()
    }

    // MARK: - Load

    func load() async {
        allMemories = (try? await repository.fetchAll()) ?? []
    }

    // MARK: - Search

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
        guard isQueryActive else {
            results = []
            return
        }
        isSearching = true
        let fts = (try? await repository.search(query: query)) ?? []
        results = await semantic.search(query: query, ftsResults: fts)
        isSearching = false

        if !results.isEmpty && isQuestion(query) && answerService.isAvailable {
            await generateAnswer()
        }
    }

    // MARK: - Save

    func saveMemory(_ memory: MemoryItem) async {
        try? await repository.save(memory)
        await semantic.indexMemory(memory)
        allMemories = (try? await repository.fetchAll()) ?? []
        if isQueryActive { await performSearch() }
    }

    // MARK: - Delete

    func deleteMemory(_ memory: MemoryItem) async {
        try? await repository.delete(id: memory.id)
        allMemories = (try? await repository.fetchAll()) ?? []
        results.removeAll { $0.id == memory.id }
    }

    // MARK: - Private

    private func generateAnswer() async {
        isAnswering = true
        answer = await answerService.answer(question: query, memories: results)
        isAnswering = false
    }

    private func isQuestion(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard t.count > 4 else { return false }
        let words = ["когда", "что", "где", "кто", "как", "почему", "зачем",
                     "when", "what", "where", "who", "how", "why", "which"]
        return words.contains(where: { t.hasPrefix($0) }) || t.hasSuffix("?")
    }
}
