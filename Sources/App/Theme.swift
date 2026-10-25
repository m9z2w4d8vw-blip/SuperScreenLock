import SwiftUI
import UIKit

enum Theme {
    static let green = Color(uiColor: Palette.green)
    static let mint = Color(uiColor: Palette.mint)
    static let rule = Color(uiColor: Palette.rule)

    /// DIN Condensed Bold, iOS's built-in relative of Bahnschrift: headlines and big numbers.
    static func headline(_ size: CGFloat) -> Font {
        .custom("DINCondensed-Bold", size: size, relativeTo: .largeTitle)
    }

    static let body = Font.body
    static let label = Font.body.weight(.semibold)
    static let small = Font.subheadline
}
