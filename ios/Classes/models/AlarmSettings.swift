import Foundation

struct AlarmSettings: Codable {
    let id: Int
    let dateTime: Date
    let assetAudioPath: String
    let volumeSettings: VolumeSettings
    let notificationSettings: NotificationSettings
    let loopAudio: Bool
    let vibrate: Bool
    let warningNotificationOnKill: Bool
    let androidFullScreenIntent: Bool

    static func from(wire: AlarmSettingsWire) -> AlarmSettings {
        return AlarmSettings(
            id: Int(truncatingIfNeeded: wire.id),
            dateTime: Date(timeIntervalSince1970: TimeInterval(wire.millisecondsSinceEpoch / 1_000)),
            assetAudioPath: wire.assetAudioPath,
            volumeSettings: VolumeSettings.from(wire: wire.volumeSettings),
            notificationSettings: NotificationSettings.from(wire: wire.notificationSettings),
            loopAudio: wire.loopAudio,
            vibrate: wire.vibrate,
            warningNotificationOnKill: wire.warningNotificationOnKill,
            androidFullScreenIntent: wire.androidFullScreenIntent
        )
    }
}
