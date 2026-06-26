import Foundation

@Observable
@MainActor
final class TimelineViewModel {
    private(set) var sections: [TimelineSection] = []
    private(set) var isLoading = false

    private let repository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        let all = (try? await repository.fetchAll()) ?? []
        sections = Self.group(all)
        isLoading = false
    }

    // MARK: - Grouping

    private static func group(_ memories: [MemoryItem]) -> [TimelineSection] {
        let calendar = Calendar.current
        var byDay: [Date: [MemoryItem]] = [:]

        for memory in memories {
            let day = calendar.startOfDay(for: memory.createdAt)
            byDay[day, default: []].append(memory)
        }

        return byDay
            .map { TimelineSection(date: $0.key, memories: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Section Model

struct TimelineSection: Identifiable {
    let date: Date
    let memories: [MemoryItem]

    var id: Date { date }

    var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return L10n.Timeline.today }
        if calendar.isDateInYesterday(date) { return L10n.Timeline.yesterday }
        return date.formatted(.dateTime.day().month(.wide).year())
    }
}
