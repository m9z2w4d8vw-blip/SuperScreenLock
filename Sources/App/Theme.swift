import SwiftUI
import UIKit

enum Theme {
    static let enamel = Color(uiColor: Palette.enamel)
    static let plate = Color(uiColor: Palette.plate)
    static let brass = Color(uiColor: Palette.brass)
    static let ivory = Color(uiColor: Palette.ivory)
    static let steel = Color(uiColor: Palette.steel)
    static let hairline = Color(uiColor: Palette.steel).opacity(0.22)

    /// SF Pro Expanded, heavy: lettering like an engraved maker's plate.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }

    @MainActor
    static func configureAppearance() {
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = Palette.brass
        segmented.backgroundColor = Palette.enamel
        segmented.setTitleTextAttributes(
            [.foregroundColor: Palette.enamel, .font: UIFont.systemFont(ofSize: 14, weight: .semibold)],
            for: .selected
        )
        segmented.setTitleTextAttributes(
            [.foregroundColor: Palette.ivory, .font: UIFont.systemFont(ofSize: 14, weight: .medium)],
            for: .normal
        )
    }
}
