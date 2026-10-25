import UIKit

/// Safe-door colors: deep green enamel, a brass dial, ivory lettering.
enum Palette {
    static let enamel = UIColor(hex: 0x10291F)
    static let plate = UIColor(hex: 0x17392C)
    static let brass = UIColor(hex: 0xD4A84B)
    static let ivory = UIColor(hex: 0xEFE7D6)
    static let steel = UIColor(hex: 0x8FA59B)
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
