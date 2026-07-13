import Foundation

struct NotificationSettings {
    var title: String
    var body: String
    var stopButton: String?
    var keepNotificationAfterAlarmEnds: Bool

    static func from(wire: NotificationSettingsWire) -> NotificationSettings {
        // NotificationSettingsWire.icon and iconColor values are ignored
        // since we can't modify the notification icon on iOS.
        return NotificationSettings(
            title: wire.title,
            body: wire.body,
            stopButton: wire.stopButton,
            keepNotificationAfterAlarmEnds: wire.keepNotificationAfterAlarmEnds
        )
    }
}
