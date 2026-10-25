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
            // A lock left over from yesterday (or an expired test lock) clears
            // here, and the app opens straight away.
            guard ShieldEngine.apply() else {
                ActivityLog.add("Lock had already ended; let the app through")
                completionHandler(.none)
                return
            }
            SharedStore.updateState { $0.pending = request }
            let settings = SharedStore.settings
            ActivityLog.add(request.source == .app ? "Unlock requested for a locked app" : "Unlock requested from the lock screen")
            Notifier.post(
                id: "ssl.unlock",
                title: "Tap to unlock",
                body: "Start your \(Format.scans(settings.requiredScans, method: settings.biometryName)) in Super Screen Lock."
            ) {
                // .defer redraws the shield, which also lets the look extension
                // record which app is on screen right now.
                completionHandler(.defer)
            }
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
