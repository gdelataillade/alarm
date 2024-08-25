import Foundation

class AlarmStorage {
    static let prefix = "flutter.__alarm_id__"
    static let shared = AlarmStorage()
    let userDefaults = UserDefaults.standard

    // Save alarm to UserDefaults
    func saveAlarm(alarmSettings: AlarmSettings) {
        let key = "\(AlarmStorage.prefix)\(alarmSettings.id)"
        if let encoded = try? JSONEncoder().encode(alarmSettings) {
            if let jsonString = String(data: encoded, encoding: .utf8) {
                userDefaults.set(encoded, forKey: key)
            } else {
                print("[AlarmStorage] Failed to convert Data to JSON String")
            }
        } else {
            print("[AlarmStorage] Failed to encode AlarmSettings")
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
            if key.hasPrefix(AlarmStorage.prefix) {
                if let jsonString = value as? String {
                    // Convert String back to Data
                    if let data = jsonString.data(using: .utf8) {
                        do {
                            // Attempt to decode the data into an AlarmSettings object
                            let alarm = try JSONDecoder().decode(AlarmSettings.self, from: data)
                            alarms.append(alarm)
                        } catch {
                            // If decoding fails, print the error
                            NSLog("[AlarmStorage] Failed to decode AlarmSettings: \(error)")
                        }
                    } else {
                        NSLog("[AlarmStorage] Failed to convert String to Data")
                    }
                } else {
                    NSLog("[AlarmStorage] Value is not of type String")
                }
            }
        }
        return alarms
    }
}