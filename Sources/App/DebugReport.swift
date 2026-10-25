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
        let text = make(model: model, now: now)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            // Files › On My iPhone › Super Screen Lock always has the latest one.
            if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? text.write(to: documents.appendingPathComponent("Super Screen Lock debug log.txt"), atomically: true, encoding: .utf8)
            }
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
        lines.append("  Recent apps in the unlock grid: \(RecentApps.all().count)")
        let activities = model.scheduledActivities
        lines.append("  Scheduled: \(activities.isEmpty ? "nothing" : activities.joined(separator: ", "))")
        lines.append("  Early-callback restarts today: \(state.rearmDay == today ? state.rearmCount : 0)")
        lines.append("  Start over if a scan fails: \(settings.restartOnFail ? "on" : "off")")
        lines.append("  Built-in apps locked by name: \(settings.extraLockedApps.count)")
        lines.append("  Block deleting apps: \(settings.blockAppDeletion ? "on" : "off")")
        lines.append("")
        lines.append("Extensions")
        let plugins = ExtensionCheck.registeredPlugIns()
        lines.append("  Registered with iOS: \(plugins.isEmpty ? "none reported" : plugins.joined(separator: ", "))")
        lines.append("  Monitor last ran: \(Heartbeat.last(Heartbeat.monitor).map(ActivityLog.timestamp) ?? "never")")
        lines.append("  Lock screen look last ran: not recorded (iOS blocks that extension from saving anything)")
        lines.append("  Lock screen buttons last ran: \(Heartbeat.last(Heartbeat.buttons).map(ActivityLog.timestamp) ?? "never")")
        lines.append("  Report extension bundled: \(ExtensionCheck.reportBundled() ? "yes" : "no")")
        let store = ManagedSettingsStore(named: .superScreenLock)
        let categories = store.shield.applicationCategories == nil ? "off" : "on"
        lines.append("  Shield store now: categories \(categories), apps locked by name \(store.shield.applications?.count ?? 0)")
        let guardOn = ManagedSettingsStore(named: .deletionGuard).application.denyAppRemoval == true
        lines.append("  Delete protection store now: \(guardOn ? "on" : "off")")
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

/// What iOS knows about this app's extensions. LaunchServices' private API is
/// fine here because this build is only ever installed with TrollStore.
enum ExtensionCheck {
    static func registeredPlugIns() -> [String] {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let proxyClass = NSClassFromString("LSApplicationProxy") else { return [] }
        let classObject = proxyClass as AnyObject
        let makeProxy = NSSelectorFromString("applicationProxyForIdentifier:")
        guard classObject.responds(to: makeProxy),
              let proxy = classObject.perform(makeProxy, with: bundleID)?.takeUnretainedValue() as? NSObject else { return [] }
        let listPlugins = NSSelectorFromString("plugInKitPlugins")
        guard proxy.responds(to: listPlugins),
              let plugins = proxy.perform(listPlugins)?.takeUnretainedValue() as? [NSObject] else { return [] }
        let readID = NSSelectorFromString("bundleIdentifier")
        return plugins.compactMap { plugin -> String? in
            guard plugin.responds(to: readID) else { return nil }
            let identifier = plugin.perform(readID)?.takeUnretainedValue() as? String
            return identifier.map { $0.components(separatedBy: ".").last ?? $0 }
        }
        .sorted()
    }

    /// The screen-time report lives in Extensions/, not PlugIns/.
    static func reportBundled() -> Bool {
        let path = Bundle.main.bundleURL.appendingPathComponent("Extensions/ActivityReport.appex").path
        return FileManager.default.fileExists(atPath: path)
    }
}
