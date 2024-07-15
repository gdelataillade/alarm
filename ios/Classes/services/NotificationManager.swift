import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    private func setupNotificationActions(hasStopButton: Bool, hasSnoozeButton: Bool, stopButtonText: String, snoozeButtonText: String) {
        var actions: [UNNotificationAction] = []
        
        if hasStopButton {
            let stopAction = UNNotificationAction(identifier: "STOP_ACTION", title: stopButtonText, options: [.destructive])
            actions.append(stopAction)
        }
        
        if hasSnoozeButton {
            let snoozeAction = UNNotificationAction(identifier: "SNOOZE_ACTION", title: snoozeButtonText, options: [])
            actions.append(snoozeAction)
        }
        
        let category = UNNotificationCategory(identifier: "ALARM_CATEGORY", actions: actions, intentIdentifiers: [], options: [])
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: completion)
    }

    func scheduleNotification(id: Int, delayInSeconds: Int, title: String, body: String, actionSettings: NotificationActionSettings, completion: @escaping (Error?) -> Void) {
        requestAuthorization { granted, error in
            guard granted, error == nil else {
                completion(error)
                return
            }
            
            self.setupNotificationActions(hasStopButton: actionSettings.hasStopButton, hasSnoozeButton: actionSettings.hasSnoozeButton, stopButtonText: actionSettings.stopButtonText, snoozeButtonText: actionSettings.snoozeButtonText)
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil
            content.categoryIdentifier = "ALARM_CATEGORY"
            content.userInfo = ["id": id, "snoozeDurationInSeconds": actionSettings.snoozeDurationInSeconds]  // Include the id as an Integer in userInfo

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
            NSLog("Stop action triggered for notification: \(notification.request.identifier)")
            SwiftAlarmPlugin.shared.stopAlarmFromNotification(id: id)

        case "SNOOZE_ACTION":
            guard let snoozeDurationInSeconds = notification.request.content.userInfo["snoozeDurationInSeconds"] as? Int else { return }
            NSLog("Snooze action triggered for notification: \(notification.request.identifier)")
            SwiftAlarmPlugin.shared.snoozeAlarmFromNotification(id: id, snoozeDurationInSeconds: snoozeDurationInSeconds)

        default:
            break
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleAction(withIdentifier: response.actionIdentifier, for: response.notification)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}