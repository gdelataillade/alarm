import Foundation

struct AlarmSettings: Codable {
    let id: Int
    let dateTime: Date
    let assetAudioPath: String
    let loopAudio: Bool
    let vibrate: Bool
    let volume: Double?
    let fadeDuration: Double
    let warningNotificationOnKill: Bool
    let androidFullScreenIntent: Bool
    let notificationSettings: NotificationSettings

    static func fromJson(json: [String: Any]) -> AlarmSettings? {
        guard let id = json["id"] as? Int,
              let dateTimeMicros = json["dateTime"] as? Int64,
              let assetAudioPath = json["assetAudioPath"] as? String,
              let loopAudio = json["loopAudio"] as? Bool,
              let vibrate = json["vibrate"] as? Bool,
              let fadeDuration = json["fadeDuration"] as? Double,
              let warningNotificationOnKill = json["warningNotificationOnKill"] as? Bool,
              let androidFullScreenIntent = json["androidFullScreenIntent"] as? Bool,
              let notificationSettingsDict = json["notificationSettings"] as? [String: Any] else {
            return nil
        }

        // Ensure the dateTimeMicros is within a valid range
        let maxValidMicroseconds: Int64 = 9223372036854775 // Corresponding to year 2262
        let safeDateTimeMicros = min(dateTimeMicros, maxValidMicroseconds)
        
        let dateTime = Date(timeIntervalSince1970: TimeInterval(safeDateTimeMicros) / 1_000_000)
        let volume = json["volume"] as? Double
        let notificationSettings = NotificationSettings.fromJson(json: notificationSettingsDict)
        
        return AlarmSettings(
            id: id,
            dateTime: dateTime,
            assetAudioPath: assetAudioPath,
            loopAudio: loopAudio,
            vibrate: vibrate,
            volume: volume,
            fadeDuration: fadeDuration,
            warningNotificationOnKill: warningNotificationOnKill,
            androidFullScreenIntent: androidFullScreenIntent,
            notificationSettings: notificationSettings
        )
    }

    static func toJson(alarmSettings: AlarmSettings) -> [String: Any] {
        let timestamp = alarmSettings.dateTime.timeIntervalSince1970
        let microsecondsPerSecond: Double = 1_000_000
        let dateTimeMicros = timestamp * microsecondsPerSecond
        
        // Ensure the microseconds value does not overflow Int64 and is within a valid range
        let maxValidMicroseconds: Double = 9223372036854775
        let safeDateTimeMicros = dateTimeMicros <= maxValidMicroseconds ? Int64(dateTimeMicros) : Int64(maxValidMicroseconds)

        return [
            "id": alarmSettings.id,
            "dateTime": safeDateTimeMicros,
            "assetAudioPath": alarmSettings.assetAudioPath,
            "loopAudio": alarmSettings.loopAudio,
            "vibrate": alarmSettings.vibrate,
            "volume": alarmSettings.volume,
            "fadeDuration": alarmSettings.fadeDuration,
            "warningNotificationOnKill": alarmSettings.warningNotificationOnKill,
            "androidFullScreenIntent": alarmSettings.androidFullScreenIntent,
            "notificationSettings": NotificationSettings.toJson(notificationSettings: alarmSettings.notificationSettings)
        ]
    }
}