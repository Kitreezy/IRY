import SwiftUI

private struct EntityExtractionServiceKey: EnvironmentKey {
    static let defaultValue: EntityExtractionService = {
        let repo = GRDBMemoryRepository(writer: AppDatabase.shared.writer)
        let extractor: any EntityExtracting
        if #available(iOS 26.0, *) {
            extractor = FoundationModelsExtractor()
        } else {
            extractor = UnavailableEntityExtractor()
        }
        return EntityExtractionService(extractor: extractor, repository: repo)
    }()
}

extension EnvironmentValues {
    var entityExtractionService: EntityExtractionService {
        get { self[EntityExtractionServiceKey.self] }
        set { self[EntityExtractionServiceKey.self] = newValue }
    }
}
