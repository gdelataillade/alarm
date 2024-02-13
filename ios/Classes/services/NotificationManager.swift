import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {} // Private initializer to ensure singleton usage

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: completion)
    }

    func scheduleNotification(id: String, delayInSeconds: Int, title: String, body: String, completion: @escaping (Error?) -> Void) {
        requestAuthorization { granted, error in
            guard granted, error == nil else {
                completion(error)
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
            let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
        }
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm-\(id)"])
    }
}
