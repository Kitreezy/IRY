import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    var results: [MemoryItem] = []
    var isLoading: Bool = false
    var error: String? = nil

    private let repository: any MemoryRepository
    private var searchTask: Task<Void, Never>?

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func onQueryChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    func performSearch() async {
        isLoading = true
        error = nil
        do {
            results = try await repository.search(query: query)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
