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

private struct ImportServiceKey: EnvironmentKey {
    static let defaultValue = ImportService(
        repository: GRDBMemoryRepository(writer: AppDatabase.shared.writer)
    )
}

extension EnvironmentValues {
    var importService: ImportService {
        get { self[ImportServiceKey.self] }
        set { self[ImportServiceKey.self] = newValue }
    }
}
