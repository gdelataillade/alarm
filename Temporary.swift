//
//  Temporary.swift
//  Dar Sunnah
//
//  Created by Bilal Larose on 23/04/2024.
//

import UserNotifications

// Exemple of Notifcation manager.
struct NotificationManager {

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() { }
    
    /// send request authorization for notification, if granted, some daily notification is setted
    func sendRequestAuthorization() {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        center.requestAuthorization(options: authOptions) { granted, error in
            print("Permission granted: \(granted)")
            if let _ = error {
                // handle error here
            }
            if granted {
//                programLocalNotif(hour: <#T##Int#>, minute: <#T##Int#>)
            }
        }
    }

}

// Add this extension below your notification manager to schedule local notifications.
//Use the same name as your notification manager
extension NotificationManager {
    
    /// Allows you to schedule local notifications
    /// - Parameters:
    ///   - nbrOfRepeat: 10 by default, this number must not be zero or negative.
    ///   - hour: Enter the scheduled wake-up time here, or the time at which the notification should go off.
    ///   - minute: Enter the scheduled wake-up time here, or the time at which the notification should go off.
    func programLocalNotif(nbrOfRepeat: Int = 10, hour: Int, minute: Int) {
        guard nbrOfRepeat > 0 else {
            // Probably better to remove fatalError and replace it with Flutter log and/or implement other logic example nbrOfRepeat += 1
            fatalError("nbrOfRepeat must be at least 1")
        }

        // Loop that creates a notification for each nbrOfRepeat, 10 by default
        for indexOfNotif in 0..<nbrOfRepeat {
            let request = UNNotificationRequest(identifier: "notif\(indexOfNotif)",
                                                content: notifContentMaker(),
                                                trigger: triggerMaker(timeInterval: indexOfNotif, at: hour, minute))
            
            center.add(request) { error in
                if error != nil {
                    // ADD the Flutter log here to catch the error with a message like: "Something went wrong in the local notifications programming [notif\(indexOf Notif)]"
                } 
                /*  // Delete these lines or uncomment them to show logs or implement your own logic.
                else {
                 // ADD the Flutter log here to catch the error with a message like: "✅ Spasm notification n°\(indexOf Notif) has been programmed")
                }
                 */
            }
        }
    }
    
    //MARK: - private func
    
    /// Sets & create the body of the notification.
    private func notifContentMaker() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "YOUR TITLE HERE IF NEEDED" // optional, you can remove it, By default, the title is the name of the application
        content.subtitle = "YOUR SUBTITLE HERE IF NEEDED" // optional, you can remove it
        content.body = "YOUR BODY HERE"
        content.sound = .default

        return content
    }

    /// Turns a date into a trigger for notification
    private func triggerMaker(timeInterval: Int, at hour: Int, _ minute: Int) -> UNCalendarNotificationTrigger {
        return UNCalendarNotificationTrigger(dateMatching: scheduleNotifications(timeInterval, hour, minute), repeats: false)
    }
    
    /// This function schedules the notification time.
    /// - Parameters:
    ///   - add: This setting allows you to have intervals of 10 seconds between each notification: add * 10
    ///   - hour: Notification trigger time (hour)
    ///   - minute: Notification trigger time (minute)
    /// - Returns: The full and effective date of triggering the notification
    private func scheduleNotifications(_ add: Int,_ hour: Int,_ minute: Int) -> DateComponents {
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = add * 10 // Adds 10 seconds interval for each notification

        return dateComponents
    }

    
}
