import UIKit

// MARK: - Brand Color
/// Palette sampled from the Joie Libre Moments app icon (sunset heart on night sky).
enum BrandColor {
    /// Hot pink / magenta — primary accent.
    static let magenta = UIColor(red: 0.914, green: 0.118, blue: 0.388, alpha: 1) // #E91E63
    /// Warm orange along the heart ribbon.
    static let orange = UIColor(red: 1.000, green: 0.549, blue: 0.000, alpha: 1) // #FF8C00
    /// Sun / top of the ribbon.
    static let sun = UIColor(red: 1.000, green: 0.843, blue: 0.000, alpha: 1) // #FFD700
    /// Soft violet on the right loop.
    static let violet = UIColor(red: 0.612, green: 0.153, blue: 0.690, alpha: 1) // #9C27B0
    /// Cyan highlight inside the heart.
    static let aqua = UIColor(red: 0.000, green: 0.737, blue: 0.831, alpha: 1) // #00BCD4
    /// Icon background night navy (use sparingly — cards stay system backgrounds).
    static let night = UIColor(red: 0.043, green: 0.082, blue: 0.153, alpha: 1) // #0B1527

    static var accent: UIColor { magenta }

    /// Full ribbon gradient, yellow → aqua.
    static var ribbon: [UIColor] { [sun, orange, magenta, violet, aqua] }
}

extension UIColor {
    /// App-wide brand accent (replaces `systemPink` in UI).
    static var brandAccent: UIColor { BrandColor.accent }
    static var brandOrange: UIColor { BrandColor.orange }
    static var brandSun: UIColor { BrandColor.sun }
    static var brandViolet: UIColor { BrandColor.violet }
    static var brandAqua: UIColor { BrandColor.aqua }
    static var brandNight: UIColor { BrandColor.night }
}
