import Foundation

/// A short rolling log every process writes to, shown under Diagnostics.
enum ActivityLog {
    struct Entry: Codable, Identifiable, Equatable {
        var id = UUID()
        var at: Date
        var source: String
        var text: String
    }

    private static let key = "log.v1"
    private static let maxEntries = 150

    static func add(_ text: String) {
        var entries = all()
        entries.append(Entry(at: Date(), source: source, text: text))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        if let data = try? JSONEncoder().encode(entries) {
            AppGroup.defaults.set(data, forKey: key)
        }
    }

    static func all() -> [Entry] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }

    private static var source: String {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if bundleID.hasSuffix(".LimitMonitor") { return "Monitor" }
        if bundleID.hasSuffix(".ShieldButtons") { return "Lock screen" }
        if bundleID.hasSuffix(".ShieldLook") { return "Lock screen" }
        return "App"
    }
}
