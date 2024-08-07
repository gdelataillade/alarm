import Foundation

struct NotificationActionSettings: Codable {
    var hasStopButton: Bool = false
    var stopButtonText: String = "Stop"

    static func fromJson(json: [String: Any]) -> NotificationActionSettings {
        return NotificationActionSettings(
            hasStopButton: json["hasStopButton"] as? Bool ?? false,
            stopButtonText: json["stopButtonText"] as? String ?? "Stop"
        )
    }

    static func toJson(notificationActionSettings: NotificationActionSettings) -> [String: Any] {
        return [
            "hasStopButton": notificationActionSettings.hasStopButton,
            "stopButtonText": notificationActionSettings.stopButtonText
        ]
    }
}