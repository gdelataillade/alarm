import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let categoryWithoutActionIdentifier = "ALARM_CATEGORY_NO_ACTION"
    private var registeredActionCategories: Set<String> = []

    override private init() {
        super.init()
        setupNotificationCategories()
        UNUserNotificationCenter.current().delegate = self
    }

    private func setupNotificationCategories() {
        let categoryWithoutAction = UNNotificationCategory(identifier: categoryWithoutActionIdentifier, actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([categoryWithoutAction])
    }

    private func registerCategoryIfNeeded(forActionTitle actionTitle: String) {
        let categoryIdentifier = "ALARM_CATEGORY_WITH_ACTION_\(actionTitle)"

        if registeredActionCategories.contains(categoryIdentifier) {
            return
        }

        let action = UNNotificationAction(identifier: "STOP_ACTION", title: actionTitle, options: [.foreground, .destructive])
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [action], intentIdentifiers: [], options: [])

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
                NSLog("[NotificationManager] Notification permission not granted. Cannot schedule alarm notification. Please request permission first.")
                let error = NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission not granted"])
                completion(error)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = notificationSettings.title
            content.body = notificationSettings.body
            content.sound = nil
            content.userInfo = ["id": id]

            if let stopButtonTitle = notificationSettings.stopButton {
                let categoryIdentifier = "ALARM_CATEGORY_WITH_ACTION_\(stopButtonTitle)"
                self.registerCategoryIfNeeded(forActionTitle: stopButtonTitle)
                content.categoryIdentifier = categoryIdentifier
            } else {
                content.categoryIdentifier = self.categoryWithoutActionIdentifier
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    func cancelNotification(id: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm-\(id)"])
    }

    func dismissNotification(id: Int) {
        let notificationIdentifier = "alarm-\(id)"
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    func handleAction(withIdentifier identifier: String?, for notification: UNNotification) {
        guard let identifier = identifier else { return }
        guard let id = notification.request.content.userInfo["id"] as? Int else { return }

        switch identifier {
        case "STOP_ACTION":
            NSLog("[NotificationManager] Stop action triggered for notification: \(notification.request.identifier)")
            SwiftAlarmPlugin.unsaveAlarm(id: id)
        default:
            break
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleAction(withIdentifier: response.actionIdentifier, for: response.notification)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}
