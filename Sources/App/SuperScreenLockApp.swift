import SwiftUI
import UserNotifications

@main
struct SuperScreenLockApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Color.white)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                model.refresh(reason: "Came to the front")
            }
        }
    }
}

/// Shows banners while the app is open and tells the UI when a banner was tapped.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(name: .sslOpenedFromNotification, object: nil)
        completionHandler()
    }
}

extension Notification.Name {
    static let sslOpenedFromNotification = Notification.Name("ssl.openedFromNotification")
}
