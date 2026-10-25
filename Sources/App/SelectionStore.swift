import FamilyControls
import Foundation

/// The always-allowed picker's selection, kept whole so the picker reopens
/// with the same apps ticked. The extensions only need the tokens, which
/// live in LockSettings.
enum SelectionStore {
    private static let key = "allowedSelection.v1"

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
