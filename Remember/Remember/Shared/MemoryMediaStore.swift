import Foundation

/// Persists photo/audio files under the app's Documents directory using
/// paths RELATIVE to that directory (e.g. "memories/UUID.jpg").
///
/// The Documents directory's absolute path is rooted in the app's
/// container, whose UUID changes on every fresh install — which Xcode
/// performs on most Debug builds. Storing an absolute path would silently
/// break media after any rebuild/reinstall even though the underlying file
/// is untouched. Only the relative path is ever persisted in the database;
/// the absolute URL is resolved fresh on every read.
enum MemoryMediaStore {
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func absoluteURL(for relativePath: String) -> URL {
        documentsDirectory.appendingPathComponent(relativePath)
    }

    static func write(_ data: Data, subdirectory: String, fileExtension: String) -> String? {
        let dir = documentsDirectory.appendingPathComponent(subdirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let relativePath = "\(subdirectory)/\(UUID().uuidString).\(fileExtension)"
        do {
            try data.write(to: documentsDirectory.appendingPathComponent(relativePath))
            return relativePath
        } catch {
            return nil
        }
    }

    static func copy(from sourceURL: URL, subdirectory: String, fileExtension: String) -> String? {
        let dir = documentsDirectory.appendingPathComponent(subdirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let relativePath = "\(subdirectory)/\(UUID().uuidString).\(fileExtension)"
        do {
            try FileManager.default.copyItem(at: sourceURL, to: documentsDirectory.appendingPathComponent(relativePath))
            return relativePath
        } catch {
            return nil
        }
    }
}

extension MemoryItem {
    var imageURL: URL? { imagePath.map(MemoryMediaStore.absoluteURL) }
    var audioURL: URL? { audioPath.map(MemoryMediaStore.absoluteURL) }
}
