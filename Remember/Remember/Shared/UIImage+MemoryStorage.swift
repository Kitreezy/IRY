import UIKit

extension UIImage {
    func saveToMemoriesDirectory() -> String? {
        guard let data = jpegData(compressionQuality: 0.8) else { return nil }
        return MemoryMediaStore.write(data, subdirectory: "memories", fileExtension: "jpg")
    }
}
