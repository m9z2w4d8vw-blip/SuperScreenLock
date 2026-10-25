import Foundation
import UserNotifications

enum Notifier {
    static func post(id: String, title: String, body: String, completion: (() -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "super-screen-lock"
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                ActivityLog.add("Notification failed: \(error.localizedDescription)")
            }
            completion?()
        }
    }

    /// For the monitor extension, which can be suspended as soon as its callback
    /// returns: waits up to two seconds for the request to land.
    static func postAndWait(id: String, title: String, body: String) {
        let done = DispatchSemaphore(value: 0)
        post(id: id, title: title, body: body) { done.signal() }
        _ = done.wait(timeout: .now() + 2)
    }
}
