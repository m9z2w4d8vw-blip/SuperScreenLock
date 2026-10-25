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
            return false
        }
        store.shield.applications = nil
        store.shield.applicationCategories = .all(except: exceptions(settings: settings, state: state))
        return true
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
