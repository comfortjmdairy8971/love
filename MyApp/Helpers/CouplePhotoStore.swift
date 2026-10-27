import UIKit
import PhotosUI

// MARK: - Couple Photo Store
/// Saves the couple photo as a JPEG in the app Documents folder (keeps UserDefaults small).
enum CouplePhotoStore {
    private static let fileName = "couplePhoto.jpg"
    private static let maxDimension: CGFloat = 1_024
    private static let jpegQuality: CGFloat = 0.82

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static var hasPhoto: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func save(_ image: UIImage) -> Bool {
        let prepared = image.preparedForCouplePhoto(maxDimension: maxDimension)
        guard let data = prepared.jpegData(compressionQuality: jpegQuality) else { return false }
        do {
            try data.write(to: fileURL, options: .atomic)
            NotificationCenter.default.post(name: .coupleProfileDidChange, object: nil)
            return true
        } catch {
            return false
        }
    }

    static func remove() {
        try? FileManager.default.removeItem(at: fileURL)
        NotificationCenter.default.post(name: .coupleProfileDidChange, object: nil)
    }
}

private extension UIImage {
    func preparedForCouplePhoto(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Photo Picker
/// Presents Apple's photo picker and optional remove action. No library permission required for picking.
enum CouplePhotoPicker {
    @MainActor
    static func present(from viewController: UIViewController, allowRemove: Bool = true) {
        let sheet = UIAlertController(title: String(localized: "Couple Photo"), message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: String(localized: "Choose Photo"), style: .default) { _ in
            presentLibrary(from: viewController)
        })
        if allowRemove, CouplePhotoStore.hasPhoto {
            sheet.addAction(UIAlertAction(title: String(localized: "Remove Photo"), style: .destructive) { _ in
                CouplePhotoStore.remove()
                Haptics.light()
            })
        }
        sheet.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        viewController.present(sheet, animated: true)
    }

    @MainActor
    static func presentLibrary(from viewController: UIViewController, onPicked: ((UIImage) -> Void)? = nil) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        let bridge = PickerBridge { image in
            if let image {
                if let onPicked {
                    onPicked(image)
                } else {
                    _ = CouplePhotoStore.save(image)
                    Haptics.success()
                }
            }
        }
        picker.delegate = bridge
        objc_setAssociatedObject(picker, &PickerBridge.assocKey, bridge, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        viewController.present(picker, animated: true)
    }
}

private final class PickerBridge: NSObject, PHPickerViewControllerDelegate {
    static var assocKey: UInt8 = 0
    private let onFinish: (UIImage?) -> Void

    init(onFinish: @escaping (UIImage?) -> Void) {
        self.onFinish = onFinish
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            onFinish(nil)
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [onFinish] object, _ in
            let image = object as? UIImage
            DispatchQueue.main.async { onFinish(image) }
        }
    }
}
