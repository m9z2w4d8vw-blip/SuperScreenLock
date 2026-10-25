import Foundation
import ManagedSettings

/// Handles the two buttons on the lock screen. Apple doesn't let this extension
/// show Face ID or open the app, so "Unlock" records the request, sends a
/// notification that opens Super Screen Lock, and asks the shield to redraw.
final class ShieldButtonsHandler: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, request: PendingUnlock(source: .app, appToken: application, createdAt: Date()), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, request: PendingUnlock(source: .category, appToken: nil, createdAt: Date()), completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, request: PendingUnlock(source: .category, appToken: nil, createdAt: Date()), completionHandler: completionHandler)
    }

    private func respond(to action: ShieldAction, request: PendingUnlock, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        Heartbeat.mark(Heartbeat.buttons)
        switch action {
        case .primaryButtonPressed:
            let settings = SharedStore.settings
            // A lock left over from yesterday (or an expired test lock): clear it
            // and close, so the app opens normally next time.
            guard ShieldEngine.shouldLock(settings: settings, state: SharedStore.state, now: Date()) else {
                ShieldEngine.apply()
                completionHandler(.close)
                ActivityLog.add("Lock had already ended, so it was cleared")
                return
            }
            // Saved first, because .defer redraws the shield right away and the
            // redraw reads it to show "Check your notifications".
            SharedStore.updateState { $0.pending = request }
            // Fire and forget, then answer iOS at once. The shield stays frozen
            // until completionHandler runs; waiting on the notification's
            // callback once hung the whole phone for 30 seconds.
            Notifier.post(
                id: "ssl.unlock",
                title: "Tap to unlock",
                body: "Start your \(Format.scans(settings.requiredScans, method: settings.biometryName)) in Super Screen Lock."
            )
            completionHandler(.defer)
            if let token = request.appToken {
                RecentApps.note([token])
            }
            ActivityLog.add(request.source == .app ? "Unlock requested for an app locked by name" : "Unlock requested from the lock screen")
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
