import Foundation

struct NotificationSettings: Codable {
    var title: String
    var body: String
    var stopButton: String?

    static func from(wire: NotificationSettingsWire) -> NotificationSettings {
        // NotificationSettingsWire.icon is ignored since we can't modify the
        // notification icon on iOS.
        return NotificationSettings(
            title: wire.title,
            body: wire.body,
            stopButton: wire.stopButton
        )
    }

    static func fromJson(json: [String: Any]) -> NotificationSettings {
        return NotificationSettings(
            title: json["title"] as! String,
            body: json["body"] as! String,
            stopButton: json["stopButton"] as? String
        )
    }

    static func toJson(notificationSettings: NotificationSettings) -> [String: Any] {
        return [
            "title": notificationSettings.title,
            "body": notificationSettings.body,
            "stopButton": notificationSettings.stopButton as Any
        ]
    }
}
