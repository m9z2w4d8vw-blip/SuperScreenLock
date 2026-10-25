import Foundation

/// JSON blobs in the App Group's UserDefaults, readable from every process.
enum SharedStore {
    private static let settingsKey = "settings.v1"
    private static let stateKey = "state.v1"

    static var settings: LockSettings {
        get { load(LockSettings.self, key: settingsKey) ?? LockSettings() }
        set { save(newValue, key: settingsKey) }
    }

    static var state: LockState {
        get { load(LockState.self, key: stateKey) ?? LockState() }
        set { save(newValue, key: stateKey) }
    }

    static func updateState(_ change: (inout LockState) -> Void) {
        var current = state
        change(&current)
        state = current
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
