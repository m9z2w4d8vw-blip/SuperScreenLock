import DeviceActivity
import Foundation
import ManagedSettings

/// iOS wakes this extension at midnight, when the daily limit is reached,
/// and when a re-lock timer runs out. It never runs on its own otherwise.
final class LimitMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .daily else { return }
        // Fires at midnight and also whenever monitoring is (re)started.
        // Yesterday's lock is keyed to yesterday's date, so applying is enough
        // to clear it on a new day without touching a lock from earlier today.
        let locked = ShieldEngine.apply()
        ActivityLog.add(locked ? "Daily schedule active; today's limit was already reached" : "Daily schedule active")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard Monitoring.isTimer(activity) else { return }
        let locked = ShieldEngine.apply(now: Date(), grace: 30)
        DeviceActivityCenter().stopMonitoring([activity])
        ActivityLog.add(locked ? "Unlock window ended; apps locked again" : "Unlock window ended")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == .daily else { return }
        let settings = SharedStore.settings
        guard settings.isEnabled else { return }
        let now = Date()

        if event == .limit {
            guard Monitoring.isPlausible(thresholdMinutes: settings.dailyLimitMinutes, now: now) else {
                ActivityLog.add("Ignored a limit callback that came too early to be real")
                Monitoring.rearmAfterEarlyEvent(settings: settings)
                return
            }
            SharedStore.updateState { state in
                state.limitReachedDay = DayKey.string(for: now)
                state.limitReachedAt = now
                state.appGrants = []
                state.allAppsUntil = nil
            }
            ShieldEngine.apply(now: now)
            ActivityLog.add("Daily limit of \(Format.duration(minutes: settings.dailyLimitMinutes)) reached; apps locked")
            Notifier.postAndWait(
                id: "ssl.limit",
                title: "Daily limit reached",
                body: "Your apps are locked until midnight. Opening one takes \(Format.scans(settings.requiredScans, method: settings.biometryName))."
            )
        } else if event == .warning {
            guard Monitoring.isPlausible(thresholdMinutes: settings.dailyLimitMinutes - 5, now: now) else { return }
            Notifier.postAndWait(
                id: "ssl.warning",
                title: "5 minutes left",
                body: "Super Screen Lock locks your apps when today's \(Format.spokenDuration(minutes: settings.dailyLimitMinutes)) are up."
            )
        }
    }
}
