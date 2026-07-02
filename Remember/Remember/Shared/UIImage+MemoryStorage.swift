import UIKit

extension UIImage {
    func saveToMemoriesDirectory() -> String? {
        guard let data = jpegData(compressionQuality: 0.8) else { return nil }
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("memories")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(UUID().uuidString + ".jpg")
        try? data.write(to: url)
        return url.path
    }
}
