import Foundation
import Photos

final class PhotosImporter: SourceImporter, @unchecked Sendable {
    let source: MemorySource = .photos

    // MARK: - SourceImporter

    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    func importNew(into repository: any MemoryRepository) async throws -> Int {
        guard await requestAccess() else { return 0 }

        let existing = try await repository.fetchAll()
        let existingTitles = Set(existing.filter { $0.source == .photos }.map { $0.title })

        let assets = fetchNamedAssets()
        var count = 0

        for asset in assets {
            let title = asset.localIdentifier
            guard !existingTitles.contains(title) else { continue }

            let content = buildContent(from: asset)
            let memory = MemoryItem(
                title: content.displayTitle,
                content: content.body,
                source: .photos,
                createdAt: asset.creationDate ?? Date(),
                updatedAt: asset.modificationDate ?? Date()
            )
            try await repository.save(memory)
            count += 1
        }
        return count
    }

    // MARK: - Private

    private func fetchNamedAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 500
        // Only assets with location or favorite — more likely to be memorable
        options.predicate = NSPredicate(format: "isFavorite == YES OR location != nil")
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    private func buildContent(from asset: PHAsset) -> (displayTitle: String, body: String) {
        var parts: [String] = []

        if let location = asset.location {
            let lat = String(format: "%.4f", location.coordinate.latitude)
            let lon = String(format: "%.4f", location.coordinate.longitude)
            parts.append("\(lat), \(lon)")
        }

        if let date = asset.creationDate {
            parts.append(date.formatted(.dateTime.day().month().year()))
        }

        let mediaType = asset.mediaType == .video ? L10n.Import.video : L10n.Import.photo
        let title = "\(mediaType) \(asset.creationDate?.formatted(.dateTime.day().month().year()) ?? "")"
        return (displayTitle: title, body: parts.joined(separator: "\n"))
    }
}
