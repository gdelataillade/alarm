import Foundation
import UserNotifications

class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private static let categoryWithoutActionIdentifier = "ALARM_CATEGORY_NO_ACTION"
    private static let categoryWithActionIdentifierPrefix = "ALARM_CATEGORY_WITH_ACTION_"
    private static let notificationIdentifierPrefix = "ALARM_NOTIFICATION_"
    private static let stopActionIdentifier = "ALARM_STOP_ACTION"
    private static let userInfoAlarmId = "ALARM_ID"

    private var registeredActionCategories: Set<String> = []

    override private init() {
        super.init()
        setupNotificationCategories()
    }

    private func setupNotificationCategories() {
        let categoryWithoutAction = UNNotificationCategory(identifier: NotificationManager.categoryWithoutActionIdentifier, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().getNotificationCategories { existingCategories in
            var categories = existingCategories
            categories.insert(categoryWithoutAction)
            UNUserNotificationCenter.current().setNotificationCategories(categories)
        }
    }

    private func registerCategoryIfNeeded(forActionTitle actionTitle: String) {
        let categoryIdentifier = "\(NotificationManager.categoryWithActionIdentifierPrefix)\(actionTitle)"

        if registeredActionCategories.contains(categoryIdentifier) {
            return
        }

        let action = UNNotificationAction(identifier: NotificationManager.stopActionIdentifier, title: actionTitle, options: [.foreground, .destructive])
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [action], intentIdentifiers: [], options: [.hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle])

        UNUserNotificationCenter.current().getNotificationCategories { existingCategories in
            var categories = existingCategories
            categories.insert(category)
            UNUserNotificationCenter.current().setNotificationCategories(categories)
            self.registeredActionCategories.insert(categoryIdentifier)
        }
    }

    func scheduleNotification(id: Int, delayInSeconds: Int, notificationSettings: NotificationSettings, completion: @escaping (Error?) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                NSLog("[SwiftAlarmPlugin] Notification permission not granted. Cannot schedule alarm notification. Please request permission first.")
                let error = NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission not granted"])
                completion(error)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = notificationSettings.title
            content.body = notificationSettings.body
            content.sound = nil
            content.userInfo = [NotificationManager.userInfoAlarmId: id]

            if let stopButtonTitle = notificationSettings.stopButton {
                let categoryIdentifier = "\(NotificationManager.categoryWithActionIdentifierPrefix)\(stopButtonTitle)"
                self.registerCategoryIfNeeded(forActionTitle: stopButtonTitle)
                content.categoryIdentifier = categoryIdentifier
            } else {
                content.categoryIdentifier = NotificationManager.categoryWithoutActionIdentifier
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: "\(NotificationManager.notificationIdentifierPrefix)\(id)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    func cancelNotification(id: Int) {
        let notificationIdentifier = "\(NotificationManager.notificationIdentifierPrefix)\(id)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    func dismissNotification(id: Int) {
        let notificationIdentifier = "\(NotificationManager.notificationIdentifierPrefix)\(id)"
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    func removeAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests(completionHandler: { requests in
            for request in requests {
                if request.identifier.starts(with: NotificationManager.notificationIdentifierPrefix) {
                    center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
                }
            }
        })
        center.getDeliveredNotifications(completionHandler: { notifs in
            for notif in notifs {
                if notif.request.identifier.starts(with: NotificationManager.notificationIdentifierPrefix) {
                    center.removeDeliveredNotifications(withIdentifiers: [notif.request.identifier])
                }
            }
        })
    }

    func handleAction(withIdentifier identifier: String?, for notification: UNNotification) {
        guard let identifier = identifier else { return }
        guard let id = notification.request.content.userInfo[NotificationManager.userInfoAlarmId] as? Int else { return }

        switch identifier {
        case NotificationManager.stopActionIdentifier:
            NSLog("[SwiftAlarmPlugin] Stop action triggered for notification: \(notification.request.identifier)")
            SwiftAlarmPlugin.stopAlarm(id: id)
        default:
            break
        }
    }

    func isAlarmNotification(_ notification: UNNotification) -> Bool {
        return notification.request.content.userInfo[NotificationManager.userInfoAlarmId] != nil
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if !isAlarmNotification(response.notification) {
            return
        }
        handleAction(withIdentifier: response.actionIdentifier, for: response.notification)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if !isAlarmNotification(notification) {
            return
        }
        completionHandler([.badge, .sound, .alert])
    }

    public func sendWarningNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = [NotificationManager.userInfoAlarmId: 0]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "notification on app kill immediate", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[SwiftAlarmPlugin] Failed to show immediate notification on app kill => error: \(error.localizedDescription)")
            } else {
                NSLog("[SwiftAlarmPlugin] Triggered immediate notification on app kill")
            }
        }
    }
}
