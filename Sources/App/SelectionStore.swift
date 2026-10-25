import FamilyControls
import Foundation

/// The pickers' selections, kept whole so each picker reopens with the same
/// apps ticked. The extensions only need the tokens, which live in LockSettings.
enum SelectionStore {
    enum Kind: String {
        case allowed = "allowedSelection.v1"
        case extraLock = "extraLockSelection.v1"
    }

    static func load(_ kind: Kind) -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: kind.rawValue),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func save(_ selection: FamilyActivitySelection, as kind: Kind) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: kind.rawValue)
    }
}
