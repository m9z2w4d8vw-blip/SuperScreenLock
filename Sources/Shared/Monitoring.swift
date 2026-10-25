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
        ActivityLog.add("Daily schedule started: limit \(Format.duration(minutes: settings.dailyLimitMinutes)), counting from \(countsPastActivity ? "midnight" : "now")")
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
    ///
    /// DeviceActivity rejects windows shorter than 15 minutes, but a window that
    /// has already started fires right away. So a 5-minute unlock gets a 16-minute
    /// window that began 11 minutes ago and ends exactly when the unlock does.
    @discardableResult
    static func scheduleTimer(endingAt end: Date) -> Bool {
        cleanUpFinishedTimers()
        let now = Date()
        let minimumWindow: TimeInterval = 16 * 60
        var finish = max(end, now.addingTimeInterval(60))
        var start = min(now.addingTimeInterval(-60), finish.addingTimeInterval(-minimumWindow))

        // Hour/minute/second components can't say "yesterday", so a window can't
        // start before midnight. Right after midnight that can make a re-lock late.
        let midnight = Calendar.current.startOfDay(for: now)
        if start < midnight {
            start = midnight
            if finish.timeIntervalSince(start) < minimumWindow {
                finish = start.addingTimeInterval(minimumWindow)
                ActivityLog.add("Re-lock pushed to \(Format.clock(finish)) because the window can't start before midnight")
            }
        }

        // Only hour, minute and second, for both ends: mixing in dates stops the callbacks.
        let parts: Set<Calendar.Component> = [.hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: start),
            intervalEnd: Calendar.current.dateComponents(parts, from: finish),
            repeats: false
        )
        let name = DeviceActivityName(timerPrefix + String(Int(finish.timeIntervalSince1970)))
        do {
            try DeviceActivityCenter().startMonitoring(name, during: schedule)
            var detail = "Re-lock scheduled for \(clockWithSeconds(finish)), window \(clockWithSeconds(start)) to \(clockWithSeconds(finish))"
            if let next = schedule.nextInterval {
                detail += "; iOS reports \(clockWithSeconds(next.start)) to \(clockWithSeconds(next.end))"
            }
            ActivityLog.add(detail)
            return true
        } catch {
            ActivityLog.add("Couldn't schedule a re-lock: \(error.localizedDescription)")
            return false
        }
    }

    static func clockWithSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
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
