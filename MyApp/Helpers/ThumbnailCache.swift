import UIKit

/// Decodes and downsizes attached photos once, instead of on every cell configuration.
enum ThumbnailCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func thumbnail(for log: ActivityLog, side: CGFloat, scale: CGFloat) -> UIImage? {
        guard let data = log.imageData else { return nil }
        let key = "\(log.id.uuidString)-\(Int(side * scale))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        guard let image = UIImage(data: data) else { return nil }
        let fill = max(side / max(image.size.width, 1), side / max(image.size.height, 1)) * scale
        let target = CGSize(width: image.size.width * fill, height: image.size.height * fill)
        guard let thumbnail = image.preparingThumbnail(of: target) else { return nil }
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
}
