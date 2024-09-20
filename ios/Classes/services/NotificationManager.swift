import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    private func setupNotificationActions(stopButton: String) {
        var actions: [UNNotificationAction] = []
        
        let stopAction = UNNotificationAction(identifier: "STOP_ACTION", title: stopButton, options: [.destructive])
        actions.append(stopAction)
        
        let category = UNNotificationCategory(identifier: "ALARM_CATEGORY", actions: actions, intentIdentifiers: [], options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    func scheduleNotification(id: Int, delayInSeconds: Int, notificationSettings: NotificationSettings, completion: @escaping (Error?) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                NSLog("[NotificationManager] Notification permission not granted. Cannot schedule alarm notification. Please request permission first.")
                let error = NSError(domain: "NotificationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission not granted"])
                completion(error)
                return
            }
            
            if let stopButton = notificationSettings.stopButton {
                self.setupNotificationActions(stopButton: stopButton)
            }
    
            let content = UNMutableNotificationContent()
            content.title = notificationSettings.title
            content.body = notificationSettings.body
            content.sound = nil
            content.categoryIdentifier = "ALARM_CATEGORY"
            content.userInfo = ["id": id]
    
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: trigger)
    
            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    func cancelNotification(id: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm-\(id)"])
    }

    func handleAction(withIdentifier identifier: String?, for notification: UNNotification) {
        guard let identifier = identifier else { return }
        guard let id = notification.request.content.userInfo["id"] as? Int else { return }

        switch identifier {
        case "STOP_ACTION":
            NSLog("[NotificationManager] Stop action triggered for notification: \(notification.request.identifier)")
            SwiftAlarmPlugin.shared.unsaveAlarm(id: id)
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