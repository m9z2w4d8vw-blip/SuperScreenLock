import Foundation

enum DayKey {
    /// "2026-10-24" in the current time zone.
    static func string(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

enum Format {
    /// "2h 15m", "45m", "1h".
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest)m" }
        if rest == 0 { return "\(hours)h" }
        return "\(hours)h \(rest)m"
    }

    /// "2 hours 15 minutes", "45 minutes", "1 hour".
    static func spokenDuration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
        let minuteText = rest == 1 ? "1 minute" : "\(rest) minutes"
        if hours == 0 { return minuteText }
        if rest == 0 { return hourText }
        return "\(hourText) \(minuteText)"
    }

    /// "4:45 PM" in the person's locale.
    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "once", "10 times".
    static func times(_ count: Int) -> String {
        count == 1 ? "once" : "\(count) times"
    }

    /// "1 Face ID scan", "10 Face ID scans".
    static func scans(_ count: Int, method: String) -> String {
        count == 1 ? "1 \(method) scan" : "\(count) \(method) scans"
    }
}
