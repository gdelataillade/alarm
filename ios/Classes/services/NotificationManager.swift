import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {} // Private initializer to ensure singleton usage

    // Checks and requests authorization to show notifications
    func ensureAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true, nil)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: completion)
            case .denied:
                completion(false, nil)
            @unknown default:
                completion(false, nil)
            }
        }
    }

    // Creates notification content
    private func createContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        return content
    }

    // Schedules a notification to be triggered after a delay
    func scheduleNotification(id: String, delayInSeconds: Int, title: String, body: String, completion: @escaping (Error?) -> Void) {
        ensureAuthorization { [weak self] granted, error in
            guard let self = self, granted, error == nil else {
                completion(error)
                return
            }
            
            let content = self.createContent(title: title, body: body)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    // Triggers a notification immediately
    func triggerNotification(id: String, title: String, body: String, completion: @escaping (Error?) -> Void) {
        ensureAuthorization { [weak self] granted, error in
            guard let self = self, granted, error == nil else {
                completion(error)
                return
            }
            
            let content = self.createContent(title: title, body: body)
            let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: nil)

            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    // Cancels a pending notification
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm-\(id)"])
    }
}
