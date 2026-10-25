import UIKit

/// Exit Guard's palette: one flat green field, white type, mint body text.
enum Palette {
    /// Background, and the ink on white buttons and checked boxes.
    static let green = UIColor(hex: 0x17704B)
    /// Body and helper text.
    static let mint = UIColor(hex: 0xDEEBE6)
    /// Hairline dividers.
    static let rule = UIColor(hex: 0x5D9B81)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
