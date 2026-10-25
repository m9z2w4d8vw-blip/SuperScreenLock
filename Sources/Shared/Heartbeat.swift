import Foundation

/// Each process stamps when it last ran. The debug log uses these to show
/// which extensions iOS is actually launching.
enum Heartbeat {
    static let monitor = "monitorExtension"
    static let look = "lookExtension"
    static let buttons = "buttonsExtension"

    static func mark(_ name: String) {
        AppGroup.defaults.set(Date().timeIntervalSince1970, forKey: "heartbeat." + name)
    }

    static func last(_ name: String) -> Date? {
        let seconds = AppGroup.defaults.double(forKey: "heartbeat." + name)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }
}
