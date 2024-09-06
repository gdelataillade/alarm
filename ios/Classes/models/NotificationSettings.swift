import Foundation

struct NotificationSettings: Codable {
    var title: String
    var body: String
    var stopButton: String?

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