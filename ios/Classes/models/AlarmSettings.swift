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
              let dateTimeMillis = json["dateTime"] as? Int64,
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
        
        let dateTime = Date(timeIntervalSince1970: TimeInterval(dateTimeMillis) / 1000)
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
}