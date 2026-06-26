import Foundation
import EventKit

final class CalendarImporter: SourceImporter, @unchecked Sendable {
    let source: MemorySource = .calendar
    private let store = EKEventStore()

    // MARK: - SourceImporter

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func importNew(into repository: any MemoryRepository) async throws -> Int {
        guard await requestAccess() else { return 0 }

        let existing = try await repository.fetchAll()
        let existingTitles = Set(existing.filter { $0.source == .calendar }.map { $0.title })

        let events = fetchRecentEvents()
        var count = 0

        for event in events {
            let title = event.title ?? L10n.Import.untitledEvent
            guard !existingTitles.contains(title) else { continue }

            let content = buildContent(from: event)
            let memory = MemoryItem(
                title: title,
                content: content,
                source: .calendar,
                createdAt: event.startDate ?? Date(),
                updatedAt: event.lastModifiedDate ?? Date()
            )
            try await repository.save(memory)
            count += 1
        }
        return count
    }

    // MARK: - Private

    private func fetchRecentEvents() -> [EKEvent] {
        let calendars = store.calendars(for: .event)
        let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    private func buildContent(from event: EKEvent) -> String {
        var parts: [String] = []
        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }
        if let notes = event.notes, !notes.isEmpty {
            parts.append(notes)
        }
        if let start = event.startDate {
            parts.append(start.formatted(.dateTime.day().month().year().hour().minute()))
        }
        return parts.joined(separator: "\n")
    }
}
