import Foundation
import ManagedSettings

/// When everything is locked by category, the shield's button handler is only
/// told the category, not the app. The shield's look extension does get the app,
/// so it leaves the app's token here for the main app to pick up.
enum ShieldStash {
    struct Entry: Codable {
        var token: ApplicationToken
        var name: String?
        var at: Date
    }

    private static let key = "shield.stash.v1"

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent("shield-stash.json")
    }

    static func remember(_ application: Application) {
        guard let token = application.token else { return }
        let entry = Entry(token: token, name: application.localizedDisplayName, at: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        // Two copies: the look extension is heavily sandboxed and short-lived,
        // so whichever write survives wins.
        if let url = fileURL {
            try? data.write(to: url)
        }
        AppGroup.defaults.set(data, forKey: key)
        ActivityLog.add("Lock screen shown for \(application.localizedDisplayName ?? "an app")")
    }

    static func latest() -> Entry? {
        var found: [Entry] = []
        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let entry = try? JSONDecoder().decode(Entry.self, from: data) {
            found.append(entry)
        }
        if let data = AppGroup.defaults.data(forKey: key),
           let entry = try? JSONDecoder().decode(Entry.self, from: data) {
            found.append(entry)
        }
        return found.max { $0.at < $1.at }
    }
}
