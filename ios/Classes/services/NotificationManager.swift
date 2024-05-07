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

extension NotificationManager {
    
    /// Allows you to schedule local notifications
    /// - Parameters:
    ///   - nbrOfRepeat: 10 by default, this number must not be zero or negative.
    ///   - hour: Enter the scheduled wake-up time here, or the time at which the notification should go off.
    ///   - minute: Enter the scheduled wake-up time here, or the time at which the notification should go off.
    func programLocalNotif(nbrOfRepeat: Int = 10, duration: Int = 10,hour: Int, minute: Int, title: String, body: String, sound: UNNotificationSound?) {
        for indexOfNotif in 0..<nbrOfRepeat {
            let request = UNNotificationRequest(identifier: "notif\(indexOfNotif)",
                                                content: notifContentMaker(title: title, body: body, sound: sound),
                                                trigger: triggerMaker(timeInterval: indexOfNotif, at: hour, minute, duration))
            
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    // ADD the Flutter log here to catch the error with a message like: "Something went wrong in the local notifications programming [notif\(indexOf Notif)]"
                } 
            }
        }
    }
    
    func cancelNotificationBis(nbrOfRepeat: Int) {
         for indexOfNotif in 0..<nbrOfRepeat {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["notif\(indexOfNotif)"]) 
        }
    }
    
    /// Sets & create the body of the notification.
    private func notifContentMaker(title: String, body: String, sound: UNNotificationSound?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        return content
    }

    /// Turns a date into a trigger for notification
    private func triggerMaker(timeInterval: Int, at hour: Int, _ minute: Int, _ duration: Int = 10) -> UNCalendarNotificationTrigger {
        return UNCalendarNotificationTrigger(dateMatching: scheduleNotifications(timeInterval, hour, minute, duration), repeats: false)
    }
    
    /// This function schedules the notification time.
    /// - Parameters:
    ///   - add: This setting allows you to have intervals of 10 seconds between each notification: add * 10
    ///   - hour: Notification trigger time (hour)
    ///   - minute: Notification trigger time (minute)
    /// - Returns: The full and effective date of triggering the notification
    private func scheduleNotifications(_ add: Int,_ hour: Int,_ minute: Int,_ duration: Int = 10) -> DateComponents {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        let secondsToAdd = add * duration

        let hoursToAdd = secondsToAdd / 3600
        let minutesToAdd = (secondsToAdd % 3600) / 60
        let secondsLeft = (secondsToAdd % 3600) % 60

        dateComponents.hour? += hoursToAdd
        dateComponents.minute? += minutesToAdd
        dateComponents.second? += secondsLeft

        // Vérifier et ajuster si nécessaire
        if let minute = dateComponents.minute, minute >= 60 {
            dateComponents.minute = minute % 60
            dateComponents.hour? += minute / 60
        }

        if let second = dateComponents.second, second >= 60 {
            dateComponents.second = second % 60
            if let minute = dateComponents.minute {
                dateComponents.minute = (minute + second / 60) % 60
                if let hour = dateComponents.hour {
                    dateComponents.hour = hour + (minute + second / 60) / 60
                }
            }
        }

        return dateComponents
    }

    
}