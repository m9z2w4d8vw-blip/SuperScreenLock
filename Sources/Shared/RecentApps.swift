import Foundation
import ManagedSettings

/// Apps the person has unlocked before, newest first, for the scan screen's grid.
/// iOS doesn't let apps see recently used apps or the app switcher, and Screen
/// Time only hands out app identities through its picker or the lock screen
/// buttons, so this list is built from what happens inside Super Screen Lock.
enum RecentApps {
    struct Entry: Codable, Equatable {
        var token: ApplicationToken
        var at: Date
    }

    private static let key = "recentApps.v1"
    private static let limit = 16

    static func all() -> [Entry] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    static func note(_ tokens: [ApplicationToken], at date: Date = Date()) {
        guard !tokens.isEmpty else { return }
        var entries = all().filter { !tokens.contains($0.token) }
        entries.insert(contentsOf: tokens.map { Entry(token: $0, at: date) }, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        save(entries)
    }

    static func forget(_ token: ApplicationToken) {
        save(all().filter { $0.token != token })
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
