import Foundation

enum L10n {
    enum Tab {
        static let search = String(localized: "tab.search")
        static let settings = String(localized: "tab.settings")
        static let people = String(localized: "tab.people")
        static let timeline = String(localized: "tab.timeline")
    }

    enum Search {
        static let title = String(localized: "search.title")
        static let prompt = String(localized: "search.prompt")
        static let emptyTitle = String(localized: "search.empty.title")
        static let emptySubtitle = String(localized: "search.empty.subtitle")
        static let notFoundTitle = String(localized: "search.notfound.title")
        static let notFoundSubtitle = String(localized: "search.notfound.subtitle")
    }

    enum CreateMemory {
        static let title = String(localized: "memory.create.title")
        static let sectionAbout = String(localized: "memory.create.section.about")
        static let sectionContent = String(localized: "memory.create.section.content")
        static let placeholderTitle = String(localized: "memory.create.placeholder.title")
        static let cancel = String(localized: "memory.create.button.cancel")
        static let save = String(localized: "memory.create.button.save")
    }

    enum MemorySource {
        static let user = String(localized: "memory.source.user")
        static let notes = String(localized: "memory.source.notes")
        static let calendar = String(localized: "memory.source.calendar")
        static let photos = String(localized: "memory.source.photos")
    }

    enum People {
        static let title = String(localized: "people.title")
        static let emptyTitle = String(localized: "people.empty.title")
        static let emptySubtitle = String(localized: "people.empty.subtitle")
        static func mentions(_ count: Int) -> String {
            let key = count == 1 ? "people.mentions.one" : "people.mentions.other"
            return String(format: NSLocalizedString(key, comment: ""), count)
        }
    }

    enum Settings {
        static let title = String(localized: "settings.title")
    }

    enum Timeline {
        static let title = String(localized: "timeline.title")
    }
}
