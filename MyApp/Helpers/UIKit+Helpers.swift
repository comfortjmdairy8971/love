import UIKit

// MARK: - Fonts
extension UIFont {
    /// Dynamic Type font with a custom weight/design that still scales with the user's text size.
    static func preferred(
        _ style: TextStyle,
        weight: Weight = .regular,
        design: UIFontDescriptor.SystemDesign = .default
    ) -> UIFont {
        let defaultSize = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
            .pointSize
        var font = UIFont.systemFont(ofSize: defaultSize, weight: weight)
        if let designed = font.fontDescriptor.withDesign(design) {
            font = UIFont(descriptor: designed, size: defaultSize)
        }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }

    /// Fixed-size rounded font (used in fixed-size artwork such as the recap card).
    static func rounded(ofSize size: CGFloat, weight: Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Factories
extension UILabel {
    static func make(
        _ text: String? = nil,
        font: UIFont,
        color: UIColor = .label,
        lines: Int = 1,
        alignment: NSTextAlignment = .natural
    ) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = lines
        label.textAlignment = alignment
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}

extension UIStackView {
    static func make(
        _ axis: NSLayoutConstraint.Axis,
        spacing: CGFloat = 0,
        alignment: Alignment = .fill,
        distribution: Distribution = .fill,
        _ views: [UIView] = []
    ) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = axis
        stack.spacing = spacing
        stack.alignment = alignment
        stack.distribution = distribution
        return stack
    }
}

extension UIImageView {
    static func symbol(_ name: String, style: UIFont.TextStyle = .body, weight: UIImage.SymbolWeight = .regular, color: UIColor) -> UIImageView {
        let imageView = UIImageView(image: UIImage(systemName: name))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: style).applying(UIImage.SymbolConfiguration(weight: weight))
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }
}

extension UIView {
    static func spacer() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        view.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        view.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)
        view.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
        return view
    }

    func pinEdges(to other: UIView, insets: NSDirectionalEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.leading),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.trailing),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom),
        ])
    }

    func pinEdges(to guide: UILayoutGuide, insets: NSDirectionalEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: guide.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: insets.leading),
            trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -insets.trailing),
            bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -insets.bottom),
        ])
    }

    func applyCardStyle(cornerRadius: CGFloat = 16) {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }
}

extension NSDirectionalEdgeInsets {
    static func all(_ value: CGFloat) -> NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(top: value, leading: value, bottom: value, trailing: value)
    }
}

// MARK: - Buttons
extension UIButton.Configuration {
    static func capsule(
        title: String,
        symbol: String? = nil,
        color: UIColor,
        font: UIFont = .preferred(.headline),
        verticalPadding: CGFloat = 12
    ) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = color
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: verticalPadding, leading: 16, bottom: verticalPadding, trailing: 16)
        if let symbol {
            config.image = UIImage(systemName: symbol)
            config.imagePadding = 6
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(font: font, scale: .small)
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = font
            return attributes
        }
        return config
    }
}

// MARK: - Reusable Small Views
/// A plain view that reports taps (and VoiceOver activation) through a closure.
class TapView: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }

    override func accessibilityActivate() -> Bool {
        guard let onTap else { return false }
        onTap()
        return true
    }
}

/// A filled, rounded text field with comfortable padding (onboarding forms).
final class RoundedTextField: UITextField {
    private let padding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

    init(placeholder: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.placeholder = placeholder
        font = .preferred(.body)
        adjustsFontForContentSizeCategory = true
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        autocapitalizationType = .words
        autocorrectionType = .no
        clearButtonMode = .whileEditing
        heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func textRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: padding) }
    override func editingRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: padding) }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect { bounds.inset(by: padding) }
}

/// A view backed by a `CAGradientLayer`, so the gradient always matches its bounds.
final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    var colors: [UIColor] = [] {
        didSet { updateColors() }
    }

    init(colors: [UIColor], start: CGPoint = CGPoint(x: 0, y: 0), end: CGPoint = CGPoint(x: 1, y: 1)) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        gradientLayer.startPoint = start
        gradientLayer.endPoint = end
        self.colors = colors
        updateColors()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: GradientView, _: UITraitCollection) in
            view.updateColors()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateColors() {
        gradientLayer.colors = colors.map { $0.resolvedColor(with: traitCollection).cgColor }
    }
}

/// A rounded tile with a white SF Symbol, used for category and ritual icons.
final class IconTileView: UIView {
    private let imageView = UIImageView()

    init(
        symbol: String,
        color: UIColor,
        side: CGFloat = 32,
        cornerRadius: CGFloat = 8,
        pointSize: CGFloat = 15,
        symbolColor: UIColor = .white
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = symbolColor
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        addSubview(imageView)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.7),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.7),
        ])
        configure(symbol: symbol, color: color)
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(symbol: String, color: UIColor, symbolColor: UIColor? = nil) {
        imageView.image = UIImage(systemName: symbol)
        backgroundColor = color
        if let symbolColor { imageView.tintColor = symbolColor }
    }
}

/// A label with padding and a capsule background (badges, chips).
final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8) {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    static func badge(font: UIFont = .preferred(.caption1, weight: .semibold)) -> PaddingLabel {
        let label = PaddingLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.clipsToBounds = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }
}

/// Simple centered icon + title + message placeholder.
final class EmptyStateView: UIView {
    init(symbol: String, title: String, message: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView.symbol(symbol, style: .title1, color: .tertiaryLabel)
        let titleLabel = UILabel.make(title, font: .preferred(.headline), alignment: .center)
        let messageLabel = UILabel.make(message, font: .preferred(.subheadline), color: .secondaryLabel, lines: 0, alignment: .center)
        let stack = UIStackView.make(.vertical, spacing: 8, alignment: .center, [icon, titleLabel, messageLabel])
        addSubview(stack)
        stack.pinEdges(to: self, insets: NSDirectionalEdgeInsets(top: 20, leading: 12, bottom: 20, trailing: 12))
        isAccessibilityElement = true
        accessibilityLabel = "\(title). \(message)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
