import Foundation

/// The app and all three extensions read and write the same App Group.
enum AppGroup {
    static let identifier = "group.com.parv.superscreenlock"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
