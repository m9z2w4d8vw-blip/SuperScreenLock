import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// What a round of scans is for.
struct UnlockRequest: Identifiable, Equatable {
    enum Target: Equatable {
        case app(ApplicationToken)
        case allApps
        case saveSettings
        case turnOff
    }

    let id = UUID()
    var target: Target
}

enum NotificationAccess: Equatable {
    case unknown
    case notDetermined
    case allowed
    case denied
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var authorization: AuthorizationStatus
    @Published private(set) var notifications: NotificationAccess = .unknown
    @Published private(set) var saved: LockSettings
    @Published var draft: LockSettings
    @Published var allowedSelection: FamilyActivitySelection
    @Published private(set) var state: LockState
    @Published var unlockRequest: UnlockRequest?
    @Published var isAlertShown = false
    @Published private(set) var alertMessage = ""
    @Published private(set) var hasSettled = false

    let biometry = Biometry.current()

    init() {
        let settings = SharedStore.settings
        saved = settings
        draft = settings
        state = SharedStore.state
        allowedSelection = SelectionStore.load()
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: Derived state

    var biometryName: String { biometry.name }

    /// Locked because today's limit is used up (not just a test lock).
    var isLimitLocked: Bool {
        saved.isEnabled && state.limitReached(on: Date())
    }

    var isShielding: Bool {
        ShieldEngine.shouldLock(settings: saved, state: state, now: Date())
    }

    var isTrialRunning: Bool {
        state.trialActive(at: Date())
    }

    var activeGrants: [AppGrant] {
        state.activeGrants(at: Date())
    }

    var allAppsOpenUntil: Date? {
        guard let until = state.allAppsUntil, until > Date() else { return nil }
        return until
    }

    var hasUnsavedChanges: Bool {
        var candidate = draft
        candidate.allowedApps = allowedSelection.applicationTokens
        candidate.isEnabled = saved.isEnabled
        candidate.biometryName = saved.biometryName
        return candidate != saved
    }

    /// Before iOS 17.4, the first day only counts usage from when the lock was turned on.
    var countingFromText: String {
        if state.countsPastActivity { return "Midnight" }
        let midnight = Calendar.current.startOfDay(for: Date())
        if let started = state.monitoringStartedAt, started > midnight {
            return Format.clock(started)
        }
        return "Midnight"
    }

    var authorizationText: String {
        switch authorization {
        case .approved: return "Allowed"
        case .denied: return "Declined"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    var notificationText: String {
        switch notifications {
        case .allowed: return "Allowed"
        case .denied: return "Off"
        case .notDetermined: return "Not asked yet"
        case .unknown: return "Checking"
        }
    }

    var scheduledActivities: [String] {
        DeviceActivityCenter().activities.map { (activity: DeviceActivityName) -> String in
            if activity == .daily { return "Daily limit" }
            if let end = Monitoring.timerEnd(activity) { return "Re-lock at \(Format.clock(end))" }
            return activity.rawValue
        }
    }

    func showAlert(_ message: String) {
        alertMessage = message
        isAlertShown = true
    }

    // MARK: Lifecycle

    /// Called on launch and every time the app comes to the front.
    func refresh() {
        authorization = AuthorizationCenter.shared.authorizationStatus
        var settings = SharedStore.settings
        if settings.biometryName != biometry.name {
            settings.biometryName = biometry.name
            SharedStore.settings = settings
        }
        if authorization == .approved {
            if settings.isEnabled && !Monitoring.isDailyRunning() {
                do {
                    try Monitoring.startDaily(settings: settings)
                    ActivityLog.add("The daily schedule was missing, so it was restarted")
                } catch {
                    ActivityLog.add("Couldn't restart the daily schedule: \(error.localizedDescription)")
                }
            }
            Monitoring.cleanUpFinishedTimers()
            ShieldEngine.apply()
        }
        let previous = saved
        saved = SharedStore.settings
        if draft == previous {
            draft = saved
        }
        state = SharedStore.state
        Task { await refreshNotificationAccess() }
        presentPendingUnlockIfNeeded()
    }

    /// FamilyControls can report its status a beat late on launch.
    func settle() async {
        refresh()
        try? await Task.sleep(nanoseconds: 700_000_000)
        refresh()
        hasSettled = true
    }

    func refreshNotificationAccess() async {
        let current = await UNUserNotificationCenter.current().notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notifications = .allowed
        case .denied:
            notifications = .denied
        case .notDetermined:
            notifications = .notDetermined
        @unknown default:
            notifications = .allowed
        }
    }

    // MARK: Permissions

    func requestScreenTime() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            ActivityLog.add("Screen Time access allowed")
        } catch {
            showAlert("Screen Time access didn't go through: \(error.localizedDescription)")
            ActivityLog.add("Screen Time access failed: \(error)")
        }
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    func requestNotifications() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            ActivityLog.add("Notification permission failed: \(error.localizedDescription)")
        }
        await refreshNotificationAccess()
    }

    // MARK: Editing

    /// 5-minute steps up to an hour, 15-minute steps after that.
    func stepLimit(up: Bool) {
        let value = draft.dailyLimitMinutes
        let step = up ? (value < 60 ? 5 : 15) : (value <= 60 ? 5 : 15)
        let next = value + (up ? step : -step)
        draft.dailyLimitMinutes = min(max(next, LockSettings.limitRange.lowerBound), LockSettings.limitRange.upperBound)
    }

    func stepScans(up: Bool) {
        let next = draft.requiredScans + (up ? 1 : -1)
        draft.requiredScans = min(max(next, LockSettings.scanRange.lowerBound), LockSettings.scanRange.upperBound)
    }

    /// While today's limit is used up, saving and turning off cost the same scans as unlocking.
    func saveTapped() {
        if isLimitLocked {
            unlockRequest = UnlockRequest(target: .saveSettings)
        } else {
            saveChanges()
        }
    }

    func turnOn() {
        persist(enabled: true, restartMonitoring: true)
        ActivityLog.add("Lock turned on")
    }

    func turnOffTapped() {
        if isLimitLocked {
            unlockRequest = UnlockRequest(target: .turnOff)
        } else {
            turnOff()
        }
    }

    private func saveChanges() {
        let limitChanged = draft.dailyLimitMinutes != saved.dailyLimitMinutes
        persist(enabled: saved.isEnabled, restartMonitoring: saved.isEnabled && limitChanged)
    }

    private func persist(enabled: Bool, restartMonitoring: Bool) {
        var next = draft
        next.allowedApps = allowedSelection.applicationTokens
        next.isEnabled = enabled
        next.biometryName = biometry.name
        let limitChanged = next.dailyLimitMinutes != saved.dailyLimitMinutes

        SharedStore.settings = next
        SelectionStore.save(allowedSelection)
        if limitChanged {
            // Let the new limit decide instead of carrying over today's lock.
            SharedStore.updateState { state in
                state.limitReachedDay = nil
                state.limitReachedAt = nil
            }
        }
        if restartMonitoring {
            do {
                try Monitoring.startDaily(settings: next)
                ActivityLog.add("Daily limit set to \(Format.duration(minutes: next.dailyLimitMinutes))")
            } catch {
                showAlert("Couldn't start the daily limit: \(error.localizedDescription)")
                ActivityLog.add("Starting the daily schedule failed: \(error)")
            }
        }
        ShieldEngine.apply()
        reloadFromStore()
    }

    private func turnOff() {
        var next = saved
        next.isEnabled = false
        SharedStore.settings = next
        Monitoring.stopAll()
        SharedStore.updateState { state in
            state.appGrants = []
            state.allAppsUntil = nil
            state.trialUntil = nil
            state.pending = nil
        }
        ShieldEngine.apply()
        reloadFromStore()
        ActivityLog.add("Lock turned off")
    }

    private func reloadFromStore() {
        saved = SharedStore.settings
        draft = saved
        allowedSelection = SelectionStore.load()
        state = SharedStore.state
    }

    // MARK: Unlocking

    /// Opens the scan screen if the lock screen's Unlock button was tapped recently.
    func presentPendingUnlockIfNeeded() {
        guard unlockRequest == nil,
              let request = state.freshPending(at: Date()),
              isShielding else { return }
        unlockRequest = UnlockRequest(target: resolveTarget(for: request))
    }

    private func resolveTarget(for request: PendingUnlock) -> UnlockRequest.Target {
        if saved.unlockScope == .allApps { return .allApps }
        if request.source == .app, let token = request.appToken { return .app(token) }
        // Tapping Unlock redraws the shield, and that redraw records the app on
        // screen. Only trust a record from that redraw or later.
        if let entry = ShieldStash.latest(), entry.at >= request.createdAt.addingTimeInterval(-2) {
            return .app(entry.token)
        }
        return .allApps
    }

    func requestUnlockAll() {
        unlockRequest = UnlockRequest(target: .allApps)
    }

    func cancelUnlock() {
        unlockRequest = nil
        SharedStore.updateState { $0.pending = nil }
        state = SharedStore.state
    }

    func finishUnlock() {
        unlockRequest = nil
    }

    /// Runs once every scan has passed. Returns a sentence for the scan screen.
    func completeUnlock(_ target: UnlockRequest.Target) -> String {
        let now = Date()
        let until = now.addingTimeInterval(TimeInterval(saved.unlockMinutes * 60))
        let relockNote = " The re-lock couldn't be scheduled, so it locks again the next time Super Screen Lock runs."
        var summary: String

        switch target {
        case .app(let token):
            SharedStore.updateState { state in
                state.appGrants.removeAll { $0.token == token }
                state.appGrants.append(AppGrant(token: token, until: until))
                if state.appGrants.count > 10 {
                    state.appGrants.removeFirst(state.appGrants.count - 10)
                }
                state.pending = nil
            }
            ShieldEngine.apply(now: now)
            summary = "Open until \(Format.clock(until)). Head back to the app."
            if !Monitoring.scheduleTimer(endingAt: until) { summary += relockNote }
            ActivityLog.add("Unlocked one app until \(Format.clock(until))")
        case .allApps:
            SharedStore.updateState { state in
                state.allAppsUntil = until
                state.pending = nil
            }
            ShieldEngine.apply(now: now)
            summary = "All apps are open until \(Format.clock(until))."
            if !Monitoring.scheduleTimer(endingAt: until) { summary += relockNote }
            ActivityLog.add("Unlocked all apps until \(Format.clock(until))")
        case .saveSettings:
            SharedStore.updateState { $0.pending = nil }
            saveChanges()
            summary = "Changes saved."
        case .turnOff:
            turnOff()
            summary = "Super Screen Lock is off."
        }

        state = SharedStore.state
        return summary
    }

    // MARK: Test lock

    func startTrial() {
        let until = Date().addingTimeInterval(15 * 60)
        SharedStore.updateState { $0.trialUntil = until }
        ShieldEngine.apply()
        Monitoring.scheduleTimer(endingAt: until)
        state = SharedStore.state
        ActivityLog.add("Started a 15-minute test lock")
    }

    func endTrial() {
        SharedStore.updateState { $0.trialUntil = nil }
        ShieldEngine.apply()
        state = SharedStore.state
        ActivityLog.add("Ended the test lock")
    }
}
