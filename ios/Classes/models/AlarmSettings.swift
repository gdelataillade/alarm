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
    let allowAlarmOverlap: Bool
    let iOSBackgroundAudio: Bool

    enum CodingKeys: String, CodingKey {
        case id, dateTime, assetAudioPath, volumeSettings, notificationSettings,
             loopAudio, vibrate, warningNotificationOnKill, androidFullScreenIntent,
             allowAlarmOverlap, iOSBackgroundAudio, volume, fadeDuration, volumeEnforced
    }

    /// Custom initializer to handle backward compatibility for older models
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode mandatory fields
        id = try container.decode(Int.self, forKey: .id)
        dateTime = try container.decode(Date.self, forKey: .dateTime)
        assetAudioPath = try container.decode(String.self, forKey: .assetAudioPath)
        notificationSettings = try container.decode(NotificationSettings.self, forKey: .notificationSettings)
        loopAudio = try container.decode(Bool.self, forKey: .loopAudio)
        vibrate = try container.decode(Bool.self, forKey: .vibrate)
        warningNotificationOnKill = try container.decode(Bool.self, forKey: .warningNotificationOnKill)
        androidFullScreenIntent = try container.decode(Bool.self, forKey: .androidFullScreenIntent)

        // Backward compatibility for `allowAlarmOverlap`
        allowAlarmOverlap = try container.decodeIfPresent(Bool.self, forKey: .allowAlarmOverlap) ?? false
        
        // Backward compatibility for `iOSBackgroundAudio`
        iOSBackgroundAudio = try container.decodeIfPresent(Bool.self, forKey: .iOSBackgroundAudio) ?? true

        // Backward compatibility for `volumeSettings`
        if let volumeSettingsDecoded = try? container.decode(VolumeSettings.self, forKey: .volumeSettings) {
            volumeSettings = volumeSettingsDecoded
        } else {
            // Reconstruct `volumeSettings` from older fields
            let volume = try container.decodeIfPresent(Double.self, forKey: .volume)
            let fadeDurationSeconds = try container.decodeIfPresent(Double.self, forKey: .fadeDuration)
            let fadeDuration = fadeDurationSeconds.map { TimeInterval($0) }
            let volumeEnforced = try container.decodeIfPresent(Bool.self, forKey: .volumeEnforced) ?? false

            volumeSettings = VolumeSettings(
                volume: volume,
                fadeDuration: fadeDuration,
                fadeSteps: [], // No equivalent for fadeSteps in older models
                volumeEnforced: volumeEnforced
            )
        }
    }

    /// Encode method to support `Encodable` protocol
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(dateTime, forKey: .dateTime)
        try container.encode(assetAudioPath, forKey: .assetAudioPath)
        try container.encode(volumeSettings, forKey: .volumeSettings)
        try container.encode(notificationSettings, forKey: .notificationSettings)
        try container.encode(loopAudio, forKey: .loopAudio)
        try container.encode(vibrate, forKey: .vibrate)
        try container.encode(warningNotificationOnKill, forKey: .warningNotificationOnKill)
        try container.encode(androidFullScreenIntent, forKey: .androidFullScreenIntent)
        try container.encode(allowAlarmOverlap, forKey: .allowAlarmOverlap)
        try container.encode(iOSBackgroundAudio, forKey: .iOSBackgroundAudio)
    }

    /// Memberwise initializer
    init(
        id: Int,
        dateTime: Date,
        assetAudioPath: String,
        volumeSettings: VolumeSettings,
        notificationSettings: NotificationSettings,
        loopAudio: Bool,
        vibrate: Bool,
        warningNotificationOnKill: Bool,
        androidFullScreenIntent: Bool,
        allowAlarmOverlap: Bool,
        iOSBackgroundAudio: Bool
    ) {
        self.id = id
        self.dateTime = dateTime
        self.assetAudioPath = assetAudioPath
        self.volumeSettings = volumeSettings
        self.notificationSettings = notificationSettings
        self.loopAudio = loopAudio
        self.vibrate = vibrate
        self.warningNotificationOnKill = warningNotificationOnKill
        self.androidFullScreenIntent = androidFullScreenIntent
        self.allowAlarmOverlap = allowAlarmOverlap
        self.iOSBackgroundAudio = iOSBackgroundAudio
    }

    /// Converts from wire model to `AlarmSettings`.
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
            androidFullScreenIntent: wire.androidFullScreenIntent,
            allowAlarmOverlap: wire.allowAlarmOverlap,
            iOSBackgroundAudio: wire.iOSBackgroundAudio
        )
    }
}
