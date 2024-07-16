import Foundation

class AlarmStorage {
    static let prefix = "__alarm_id__"
    static let shared = AlarmStorage()
    let userDefaults = UserDefaults.standard

    // Save alarm to UserDefaults
    func saveAlarm(alarmSettings: AlarmSettings) {
        let key = "\(AlarmStorage.prefix)\(alarmSettings.id)"
        if let encoded = try? JSONEncoder().encode(alarmSettings) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    // Remove alarm from UserDefaults
    func unsaveAlarm(id: Int) {
        let key = "\(AlarmStorage.prefix)\(id)"
        userDefaults.removeObject(forKey: key)
    }

    // Get all saved alarms from UserDefaults
    func getSavedAlarms() -> [AlarmSettings] {
        var alarms: [AlarmSettings] = []
        for (key, value) in userDefaults.dictionaryRepresentation() {
            if key.hasPrefix(AlarmStorage.prefix), let data = value as? Data, let alarm = try? JSONDecoder().decode(AlarmSettings.self, from: data) {
                alarms.append(alarm)
            }
        }
        return alarms
    }
}