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

    enum CodingKeys: String, CodingKey {
        case id, dateTime, assetAudioPath, volumeSettings, notificationSettings,
             loopAudio, vibrate, warningNotificationOnKill, androidFullScreenIntent,
             allowAlarmOverlap
    }

    // Custom initializer to handle missing keys
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        dateTime = try container.decode(Date.self, forKey: .dateTime)
        assetAudioPath = try container.decode(String.self, forKey: .assetAudioPath)
        volumeSettings = try container.decode(VolumeSettings.self, forKey: .volumeSettings)
        notificationSettings = try container.decode(NotificationSettings.self, forKey: .notificationSettings)
        loopAudio = try container.decode(Bool.self, forKey: .loopAudio)
        vibrate = try container.decode(Bool.self, forKey: .vibrate)
        warningNotificationOnKill = try container.decode(Bool.self, forKey: .warningNotificationOnKill)
        androidFullScreenIntent = try container.decode(Bool.self, forKey: .androidFullScreenIntent)
        allowAlarmOverlap = try container.decodeIfPresent(Bool.self, forKey: .allowAlarmOverlap) ?? false
    }

    // Memberwise initializer
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
        allowAlarmOverlap: Bool
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
    }

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
            allowAlarmOverlap: wire.allowAlarmOverlap
        )
    }
}