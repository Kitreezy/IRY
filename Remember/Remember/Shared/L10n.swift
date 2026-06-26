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
        static let answerLabel = String(localized: "search.answer.label")
        static let answerLoading = String(localized: "search.answer.loading")
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

    enum Import {
        static let untitledEvent = String(localized: "import.untitled.event")
        static let photo = String(localized: "import.media.photo")
        static let video = String(localized: "import.media.video")
    }

    enum Capture {
        static let whatTitle = String(localized: "capture.what.title")
        static let whatSubtitle = String(localized: "capture.what.subtitle")
        static let whyTitle = String(localized: "capture.why.title")
        static let whySubtitle = String(localized: "capture.why.subtitle")
        static let whyPlaceholder = String(localized: "capture.why.placeholder")
        static let titlePlaceholder = String(localized: "capture.title.placeholder")
        static let contentPlaceholder = String(localized: "capture.content.placeholder")
        static let next = String(localized: "capture.button.next")
        static let save = String(localized: "capture.button.save")
        static let cancel = String(localized: "capture.button.cancel")
    }

    enum MemoryDetail {
        static let whyTitle = String(localized: "memory.detail.why.title")
        static let relatedTitle = String(localized: "memory.detail.related.title")
    }

    enum EntityType {
        static let person = String(localized: "entity.type.person")
        static let place = String(localized: "entity.type.place")
        static let topic = String(localized: "entity.type.topic")
        static let company = String(localized: "entity.type.company")
    }

    enum Settings {
        static let title = String(localized: "settings.title")
        static let sectionSources = String(localized: "settings.section.sources")
        static let importCalendar = String(localized: "settings.import.calendar")
        static let importPhotos = String(localized: "settings.import.photos")
        static func importResult(_ count: Int, sourceName: String) -> String {
            String(format: NSLocalizedString("settings.import.result", comment: ""), count, sourceName)
        }
    }

    enum Timeline {
        static let title = String(localized: "timeline.title")
        static let today = String(localized: "timeline.today")
        static let yesterday = String(localized: "timeline.yesterday")
        static let emptyTitle = String(localized: "timeline.empty.title")
        static let emptySubtitle = String(localized: "timeline.empty.subtitle")
    }
}
