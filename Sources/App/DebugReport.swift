import DeviceActivity
import Foundation
import ManagedSettings

/// Builds the .txt file Diagnostics shares: a status snapshot, then the full log.
@MainActor
enum DebugReport {
    private static let prefix = "SuperScreenLock-debug-"

    static func write(model: AppModel) -> URL? {
        let now = Date()
        let folder = FileManager.default.temporaryDirectory
        if let old = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for file in old where file.lastPathComponent.hasPrefix(prefix) {
                try? FileManager.default.removeItem(at: file)
            }
        }
        let url = folder.appendingPathComponent(prefix + fileStamp(now) + ".txt")
        do {
            try make(model: model, now: now).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            ActivityLog.add("Couldn't write the debug log file: \(error.localizedDescription)")
            return nil
        }
    }

    static func make(model: AppModel, now: Date) -> String {
        let settings = model.saved
        let state = model.state
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let today = DayKey.string(for: now)

        var lines: [String] = []
        lines.append("Super Screen Lock debug log")
        lines.append("Exported \(ActivityLog.timestamp(now)) (\(TimeZone.current.identifier))")
        lines.append("App \(version) (build \(build)), \(ProcessInfo.processInfo.operatingSystemVersionString), \(deviceModel())")
        lines.append("")
        lines.append("Status")
        lines.append("  Screen Time access: \(model.authorizationText)")
        lines.append("  Notifications: \(model.notificationText)")
        lines.append("  Unlock method: \(model.biometryName)")
        lines.append("  Lock: \(settings.isEnabled ? "on" : "off")")
        lines.append("  Daily limit: \(Format.duration(minutes: settings.dailyLimitMinutes)), reached today: \(state.limitReached(on: now) ? "yes, at \(state.limitReachedAt.map(ActivityLog.timestamp) ?? "?")" : "no")")
        lines.append("  Counting today from: \(model.countingFromText)")
        lines.append("  Scans to unlock: \(settings.requiredScans)")
        lines.append("  Each unlock lasts: \(Format.spokenDuration(minutes: settings.unlockMinutes))\(settings.unlockIsCustom ? " (custom)" : "")")
        lines.append("  Scanning opens: \(settings.unlockScope == .allApps ? "all apps" : "that app")")
        lines.append("  Always allowed apps: \(settings.allowedApps.count)")
        lines.append("  Apps locked right now: \(model.isShielding ? "yes" : "no")")
        lines.append("  Test lock until: \(state.trialUntil.map(ActivityLog.timestamp) ?? "none")")
        lines.append("  All apps open until: \(state.allAppsUntil.map(ActivityLog.timestamp) ?? "none")")
        let grants = state.appGrants.map { ActivityLog.timestamp($0.until) }
        lines.append("  Single-app unlocks: \(grants.isEmpty ? "none" : grants.joined(separator: ", "))")
        if let pending = state.pending {
            lines.append("  Pending unlock: from the \(pending.source == .app ? "app" : "category") shield, tapped \(ActivityLog.timestamp(pending.createdAt))")
        } else {
            lines.append("  Pending unlock: none")
        }
        if let entry = ShieldStash.latest() {
            lines.append("  Last lock screen record: \(entry.name ?? "unnamed app") at \(ActivityLog.timestamp(entry.at))")
        } else {
            lines.append("  Last lock screen record: none")
        }
        let activities = model.scheduledActivities
        lines.append("  Scheduled: \(activities.isEmpty ? "nothing" : activities.joined(separator: ", "))")
        lines.append("  Early-callback restarts today: \(state.rearmDay == today ? state.rearmCount : 0)")
        lines.append("")
        lines.append("Log, oldest first")
        let log = ActivityLog.textLog()
        lines.append(log.isEmpty ? "(empty)" : log)
        return lines.joined(separator: "\n")
    }

    private static func fileStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    /// "iPhone14,5" and so on.
    private static func deviceModel() -> String {
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
