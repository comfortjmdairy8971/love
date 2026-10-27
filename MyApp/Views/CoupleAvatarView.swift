import UIKit

// MARK: - Couple Avatar
/// Circular couple photo, or a heart placeholder when none is set.
final class CoupleAvatarView: UIView {
    var onTap: (() -> Void)?

    private let imageView = UIImageView()
    private let placeholder = IconTileView(
        symbol: "heart.fill",
        color: .brandAccent,
        side: 48,
        cornerRadius: 24,
        pointSize: 20
    )
    private let cameraBadge = UIImageView()

    init(side: CGFloat = 48, showsCameraBadge: Bool = true) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = side / 2
        imageView.layer.cornerCurve = .continuous
        imageView.isHidden = true

        cameraBadge.translatesAutoresizingMaskIntoConstraints = false
        cameraBadge.image = UIImage(systemName: "camera.circle.fill")
        cameraBadge.tintColor = .brandAccent
        cameraBadge.backgroundColor = .systemBackground
        cameraBadge.layer.cornerRadius = 10
        cameraBadge.clipsToBounds = true
        cameraBadge.isHidden = !showsCameraBadge
        cameraBadge.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18)

        addSubview(placeholder)
        addSubview(imageView)
        addSubview(cameraBadge)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cameraBadge.widthAnchor.constraint(equalToConstant: 20),
            cameraBadge.heightAnchor.constraint(equalToConstant: 20),
            cameraBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2),
            cameraBadge.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 2),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = String(localized: "Couple photo")
        accessibilityHint = String(localized: "Double tap to add or change photo")
        accessibilityIdentifier = AccessibilityID.Dashboard.couplePhoto
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload() {
        if let photo = CouplePhotoStore.load() {
            imageView.image = photo
            imageView.isHidden = false
            placeholder.isHidden = true
        } else {
            imageView.image = nil
            imageView.isHidden = true
            placeholder.isHidden = false
        }
    }

    @objc private func handleTap() {
        Haptics.light()
        onTap?()
    }
}
