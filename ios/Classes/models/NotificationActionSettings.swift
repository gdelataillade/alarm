import Foundation

struct NotificationActionSettings: Codable {
    var hasStopButton: Bool = false
    var hasSnoozeButton: Bool = false
    var stopButtonText: String = "Stop"
    var snoozeButtonText: String = "Snooze"
    var snoozeDurationInSeconds: Int = 9 * 60

    static func fromJson(json: [String: Any]) -> NotificationActionSettings {
        return NotificationActionSettings(
            hasStopButton: json["hasStopButton"] as? Bool ?? false,
            hasSnoozeButton: json["hasSnoozeButton"] as? Bool ?? false,
            stopButtonText: json["stopButtonText"] as? String ?? "Stop",
            snoozeButtonText: json["snoozeButtonText"] as? String ?? "Snooze",
            snoozeDurationInSeconds: json["snoozeDurationInSeconds"] as? Int ?? 9 * 60
        )
    }
}