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

    init(side: CGFloat = 48) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = side / 2
        imageView.layer.cornerCurve = .continuous
        imageView.isHidden = true

        addSubview(placeholder)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .image
        accessibilityLabel = String(localized: "Couple photo")
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
}
