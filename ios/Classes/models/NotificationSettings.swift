import Foundation

struct NotificationSettings: Codable {
    var title: String
    var body: String
    var stopButton: String?
    var keepNotificationAfterAlarmEnds: Bool = false

    static func from(wire: NotificationSettingsWire) -> NotificationSettings {
        // NotificationSettingsWire.icon is ignored since we can't modify the
        // notification icon on iOS.
        return NotificationSettings(
            title: wire.title,
            body: wire.body,
            stopButton: wire.stopButton,
            keepNotificationAfterAlarmEnds: wire.keepNotificationAfterAlarmEnds
        )
    }

    static func fromJson(json: [String: Any]) -> NotificationSettings {
        return NotificationSettings(
            title: json["title"] as! String,
            body: json["body"] as! String,
            stopButton: json["stopButton"] as? String,
            keepNotificationAfterAlarmEnds: json["keepNotificationAfterAlarmEnds"] as! Bool 
        )
    }

    static func toJson(notificationSettings: NotificationSettings) -> [String: Any] {
        return [
            "title": notificationSettings.title,
            "body": notificationSettings.body,
            "stopButton": notificationSettings.stopButton as Any,
            "keepNotificationAfterAlarmEnds": notificationSettings.keepNotificationAfterAlarmEnds
        ]
    }
}
