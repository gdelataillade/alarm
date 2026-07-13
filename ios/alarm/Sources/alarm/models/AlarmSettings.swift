import Foundation

struct AlarmSettings {
    let id: Int
    let dateTime: Date
    let assetAudioPath: String?
    let volumeSettings: VolumeSettings
    let notificationSettings: NotificationSettings
    let loopAudio: Bool
    let vibrate: Bool
    let warningNotificationOnKill: Bool
    let androidFullScreenIntent: Bool
    let allowAlarmOverlap: Bool
    let allowSameSecondScheduling: Bool
    let iOSBackgroundAudio: Bool

    /// Converts from wire model to `AlarmSettings`.
    static func from(wire: AlarmSettingsWire) -> AlarmSettings {
        return AlarmSettings(
            id: Int(truncatingIfNeeded: wire.id),
            dateTime: Date(timeIntervalSince1970: TimeInterval(wire.millisecondsSinceEpoch) / 1_000.0),
            assetAudioPath: wire.assetAudioPath,
            volumeSettings: VolumeSettings.from(wire: wire.volumeSettings),
            notificationSettings: NotificationSettings.from(wire: wire.notificationSettings),
            loopAudio: wire.loopAudio,
            vibrate: wire.vibrate,
            warningNotificationOnKill: wire.warningNotificationOnKill,
            androidFullScreenIntent: wire.androidFullScreenIntent,
            allowAlarmOverlap: wire.allowAlarmOverlap,
            allowSameSecondScheduling: wire.allowSameSecondScheduling,
            iOSBackgroundAudio: wire.iOSBackgroundAudio
        )
    }
}
