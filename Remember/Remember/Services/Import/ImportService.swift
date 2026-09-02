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
    ///
    /// Импортеры не пересекаются по данным: Calendar и Photos читают разные
    /// системные хранилища. Последовательный запуск означал, что запрос прав и
    /// выборка фото ждали окончания работы с календарём. Здесь они идут
    /// одновременно, а порядок результатов сохраняется — на него опираются тесты
    /// и UI настроек.
    @discardableResult
    func importAll() async -> [ImportResult] {
        let repository = self.repository
        return await importers.concurrentMap(maxConcurrent: importers.count) { importer in
            await Self.run(importer, into: repository)
        }
    }

    /// Import from a single specific source.
    @discardableResult
    func importFrom(_ source: MemorySource) async -> ImportResult {
        guard let importer = importers.first(where: { $0.source == source }) else {
            return ImportResult(source: source, imported: 0, failed: 0)
        }
        return await Self.run(importer, into: repository)
    }

    // MARK: - Private

    private static func run(
        _ importer: any SourceImporter,
        into repository: any MemoryRepository
    ) async -> ImportResult {
        guard await importer.requestAccess() else {
            return ImportResult(source: importer.source, imported: 0, failed: 0)
        }
        do {
            let count = try await importer.importNew(into: repository)
            return ImportResult(source: importer.source, imported: count, failed: 0)
        } catch {
            return ImportResult(source: importer.source, imported: 0, failed: 1)
        }
    }
}
