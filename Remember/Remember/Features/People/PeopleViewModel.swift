import Foundation
import Observation

@Observable
@MainActor
final class PeopleViewModel {
    struct PersonEntry: Identifiable {
        let id: String
        var name: String
        var mentions: Int
        var memories: [MemoryItem]
    }

    var people: [PersonEntry] = []
    var isLoading = false

    private let repository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        let entities = (try? await repository.fetchEntities(ofType: .person)) ?? []
        let allMemories = (try? await repository.fetchAll()) ?? []
        let memoriesById = Dictionary(uniqueKeysWithValues: allMemories.map { ($0.id, $0) })

        var grouped: [String: [MemoryItem]] = [:]
        for entity in entities {
            let name = entity.value
            if let memory = memoriesById[entity.memoryId] {
                grouped[name, default: []].append(memory)
            }
        }

        people = grouped
            .map { name, memories in
                PersonEntry(
                    id: name,
                    name: name,
                    mentions: memories.count,
                    memories: memories.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.mentions > $1.mentions }

        isLoading = false
    }
}
