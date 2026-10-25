import DeviceActivity
import Foundation

extension DeviceActivityName {
    static let daily = Self("ssl.daily")
}

extension DeviceActivityEvent.Name {
    static let limit = Self("ssl.limit")
    static let warning = Self("ssl.warning")
}

/// Everything that schedules wake-ups for the LimitMonitor extension.
enum Monitoring {
    static let timerPrefix = "ssl.timer."

    /// iOS 17.4 added `includesPastActivity`. Before that, usage only counts
    /// from the moment monitoring starts on the first day.
    static var countsPastActivity: Bool {
        if #available(iOS 17.4, *) { return true }
        return false
    }

    // MARK: Daily limit

    /// (Re)starts the midnight-to-midnight schedule with the limit as an event.
    /// No apps or categories are given, which makes iOS count all screen time.
    static func startDaily(settings: LockSettings) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])
        guard settings.isEnabled else { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            .limit: event(minutes: settings.dailyLimitMinutes)
        ]
        if settings.dailyLimitMinutes >= 20 {
            events[.warning] = event(minutes: settings.dailyLimitMinutes - 5)
        }

        // Written first: the monitor can be called before startMonitoring returns.
        SharedStore.updateState { state in
            state.monitoringStartedAt = Date()
            state.countsPastActivity = Monitoring.countsPastActivity
        }
        try center.startMonitoring(.daily, during: schedule, events: events)
    }

    static func isDailyRunning() -> Bool {
        DeviceActivityCenter().activities.contains(.daily)
    }

    static func stopAll() {
        DeviceActivityCenter().stopMonitoring()
    }

    private static func event(minutes: Int) -> DeviceActivityEvent {
        let threshold = DateComponents(hour: minutes / 60, minute: minutes % 60)
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(threshold: threshold, includesPastActivity: true)
        }
        return DeviceActivityEvent(threshold: threshold)
    }

    /// Some iOS versions fire threshold events the moment monitoring starts.
    /// Screen time can't exceed wall-clock time, so a callback that arrives
    /// sooner than the threshold could possibly be reached is ignored.
    static func isPlausible(thresholdMinutes: Int, now: Date) -> Bool {
        let state = SharedStore.state
        var countingFrom = Calendar.current.startOfDay(for: now)
        if !state.countsPastActivity, let started = state.monitoringStartedAt, started > countingFrom {
            countingFrom = started
        }
        return now.timeIntervalSince(countingFrom) + 90 >= TimeInterval(thresholdMinutes * 60)
    }

    /// An ignored early event is used up for the day, so restart monitoring to
    /// get a real one. Capped at three restarts a day in case iOS keeps misfiring.
    static func rearmAfterEarlyEvent(settings: LockSettings) {
        let today = DayKey.string(for: Date())
        var allowed = false
        SharedStore.updateState { state in
            if state.rearmDay != today {
                state.rearmDay = today
                state.rearmCount = 0
            }
            if state.rearmCount < 3 {
                state.rearmCount += 1
                allowed = true
            }
        }
        guard allowed else {
            ActivityLog.add("Ignored another early limit callback; not restarting again today")
            return
        }
        do {
            try startDaily(settings: settings)
            ActivityLog.add("Restarted the daily limit after an early callback")
        } catch {
            ActivityLog.add("Couldn't restart the daily limit: \(error.localizedDescription)")
        }
    }

    // MARK: One-off timers (re-locks and the test lock)

    /// Wakes the monitor at `end` so it can lock things again.
    @discardableResult
    static func scheduleTimer(endingAt end: Date) -> Bool {
        cleanUpFinishedTimers()
        let now = Date()
        // DeviceActivity rejects intervals shorter than 15 minutes, so the window
        // opens a minute in the past and never closes sooner than 15 minutes out.
        let start = now.addingTimeInterval(-60)
        let finish = max(end, start.addingTimeInterval(16 * 60))
        let parts: Set<Calendar.Component> = [.hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: start),
            intervalEnd: Calendar.current.dateComponents(parts, from: finish),
            repeats: false
        )
        let name = DeviceActivityName(timerPrefix + String(Int(finish.timeIntervalSince1970)))
        do {
            try DeviceActivityCenter().startMonitoring(name, during: schedule)
            return true
        } catch {
            ActivityLog.add("Couldn't schedule a re-lock: \(error.localizedDescription)")
            return false
        }
    }

    static func cleanUpFinishedTimers() {
        let center = DeviceActivityCenter()
        let cutoff = Date().addingTimeInterval(-120)
        let finished = center.activities.filter { activity in
            guard let end = timerEnd(activity) else { return false }
            return end < cutoff
        }
        if !finished.isEmpty {
            center.stopMonitoring(finished)
        }
    }

    static func isTimer(_ activity: DeviceActivityName) -> Bool {
        activity.rawValue.hasPrefix(timerPrefix)
    }

    static func timerEnd(_ activity: DeviceActivityName) -> Date? {
        guard isTimer(activity),
              let seconds = TimeInterval(activity.rawValue.dropFirst(timerPrefix.count)) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
