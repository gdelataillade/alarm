import Foundation

struct AlarmSettings: Codable {
    let id: Int
    let dateTime: Date
    let assetAudioPath: String
    let loopAudio: Bool
    let vibrate: Bool
    let volume: Double?
    let fadeDuration: Double
    let notificationTitle: String
    let notificationBody: String
    let enableNotificationOnKill: Bool
    let androidFullScreenIntent: Bool
    let notificationActionSettings: NotificationActionSettings

    static func fromJson(json: [String: Any]) -> AlarmSettings? {
        guard let id = json["id"] as? Int,
              let dateTimeMicros = json["dateTime"] as? Int64,
              let assetAudioPath = json["assetAudioPath"] as? String,
              let loopAudio = json["loopAudio"] as? Bool,
              let vibrate = json["vibrate"] as? Bool,
              let fadeDuration = json["fadeDuration"] as? Double,
              let notificationTitle = json["notificationTitle"] as? String,
              let notificationBody = json["notificationBody"] as? String,
              let enableNotificationOnKill = json["enableNotificationOnKill"] as? Bool,
              let androidFullScreenIntent = json["androidFullScreenIntent"] as? Bool,
              let notificationActionSettingsDict = json["notificationActionSettings"] as? [String: Any] else {
            return nil
        }

        // Ensure the dateTimeMicros is within a valid range
        let maxValidMicroseconds: Int64 = 9223372036854775 // Corresponding to year 2262
        let safeDateTimeMicros = min(dateTimeMicros, maxValidMicroseconds)
        
        let dateTime = Date(timeIntervalSince1970: TimeInterval(safeDateTimeMicros) / 1_000_000)
        let volume = json["volume"] as? Double
        let notificationActionSettings = NotificationActionSettings.fromJson(json: notificationActionSettingsDict)
        
        return AlarmSettings(
            id: id,
            dateTime: dateTime,
            assetAudioPath: assetAudioPath,
            loopAudio: loopAudio,
            vibrate: vibrate,
            volume: volume,
            fadeDuration: fadeDuration,
            notificationTitle: notificationTitle,
            notificationBody: notificationBody,
            enableNotificationOnKill: enableNotificationOnKill,
            androidFullScreenIntent: androidFullScreenIntent,
            notificationActionSettings: notificationActionSettings
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
            "notificationTitle": alarmSettings.notificationTitle,
            "notificationBody": alarmSettings.notificationBody,
            "enableNotificationOnKill": alarmSettings.enableNotificationOnKill,
            "androidFullScreenIntent": alarmSettings.androidFullScreenIntent,
            "notificationActionSettings": NotificationActionSettings.toJson(notificationActionSettings: alarmSettings.notificationActionSettings)
        ]
    }
}