import UIKit

// MARK: - Couple Photo Store
/// Reads/removes a leftover couple photo JPEG in Documents (picking photos is no longer in the app).
enum CouplePhotoStore {
    private static let fileName = "couplePhoto.jpg"

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
        NotificationCenter.default.post(name: .coupleProfileDidChange, object: nil)
    }
}
