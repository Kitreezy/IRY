import Foundation

/// Orchestrates all source importers. Run on launch and on demand from Settings.
actor ImportService {
    private let importers: [any SourceImporter]
    private let repository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.repository = repository
        self.importers = [
            CalendarImporter(),
            PhotosImporter()
        ]
    }

    init(repository: any MemoryRepository, importers: [any SourceImporter]) {
        self.repository = repository
        self.importers = importers
    }

    /// Runs all importers that have permission granted, returns results per source.
    @discardableResult
    func importAll() async -> [ImportResult] {
        var results: [ImportResult] = []
        for importer in importers {
            let hasAccess = await importer.requestAccess()
            guard hasAccess else {
                results.append(ImportResult(source: importer.source, imported: 0, failed: 0))
                continue
            }
            do {
                let count = try await importer.importNew(into: repository)
                results.append(ImportResult(source: importer.source, imported: count, failed: 0))
            } catch {
                results.append(ImportResult(source: importer.source, imported: 0, failed: 1))
            }
        }
        return results
    }

    /// Import from a single specific source.
    @discardableResult
    func importFrom(_ source: MemorySource) async -> ImportResult {
        guard let importer = importers.first(where: { $0.source == source }) else {
            return ImportResult(source: source, imported: 0, failed: 0)
        }
        guard await importer.requestAccess() else {
            return ImportResult(source: source, imported: 0, failed: 0)
        }
        do {
            let count = try await importer.importNew(into: repository)
            return ImportResult(source: source, imported: count, failed: 0)
        } catch {
            return ImportResult(source: source, imported: 0, failed: 1)
        }
    }
}
