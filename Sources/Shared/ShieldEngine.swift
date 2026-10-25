import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let superScreenLock = Self("superScreenLock")
}

/// The single place that decides what's locked. The app and every extension
/// call `apply()` instead of touching ManagedSettings directly.
enum ShieldEngine {
    /// Whether apps should be covered right now, before per-app unlocks.
    static func shouldLock(settings: LockSettings, state: LockState, now: Date) -> Bool {
        let byLimit = settings.isEnabled && state.limitReached(on: now)
        return (byLimit || state.trialActive(at: now)) && !state.allAppsOpen(at: now)
    }

    /// Drops expired unlocks, then writes the matching shield.
    /// `grace` treats anything ending within that many seconds as already over,
    /// because DeviceActivity can wake the monitor slightly early.
    /// Returns whether apps are locked afterwards.
    @discardableResult
    static func apply(now: Date = Date(), grace: TimeInterval = 0) -> Bool {
        let settings = SharedStore.settings
        var state = SharedStore.state
        let before = state
        state.prune(asOf: now.addingTimeInterval(grace))
        if state != before {
            SharedStore.state = state
        }

        let store = ManagedSettingsStore(named: .superScreenLock)
        guard shouldLock(settings: settings, state: state, now: now) else {
            store.clearAllSettings()
            noteChange("clear", "Shield off: every app is open")
            return false
        }
        let open = exceptions(settings: settings, state: state)
        store.shield.applications = nil
        store.shield.applicationCategories = .all(except: open)
        noteChange("locked:\(open.count)", "Shield on: everything locked except \(open.count) app\(open.count == 1 ? "" : "s")")
        return true
    }

    /// apply() runs constantly, so only log when the result differs from last time.
    private static func noteChange(_ signature: String, _ message: String) {
        let key = "shield.lastApplied"
        guard AppGroup.defaults.string(forKey: key) != signature else { return }
        AppGroup.defaults.set(signature, forKey: key)
        ActivityLog.add(message)
    }

    /// iOS takes at most 50 exceptions: always-allowed apps get the first 40,
    /// the newest unlocks fill the rest.
    static func exceptions(settings: LockSettings, state: LockState) -> Set<ApplicationToken> {
        var result = Set(settings.allowedApps.prefix(40))
        for grant in state.appGrants.reversed() where result.count < 50 {
            result.insert(grant.token)
        }
        return result
    }
}
