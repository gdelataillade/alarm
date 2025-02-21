import Flutter
import os.log

public class AlarmApiImpl: NSObject, AlarmApi {
    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "AlarmApiImpl")

    private let registrar: FlutterPluginRegistrar
    private let manager: AlarmManager

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        self.manager = AlarmManager(registrar: registrar)
    }

    func setAlarm(alarmSettings: AlarmSettingsWire, completion: @escaping (Result<Void, Error>) -> Void) {
        let alarmSettings = AlarmSettings.from(wire: alarmSettings)
        os_log(.info, log: AlarmApiImpl.logger, "Set alarm called with: %@", String(describing: alarmSettings))

        Task {
            await self.manager.setAlarm(alarmSettings: alarmSettings)
            completion(.success(()))
        }
    }

    func stopAlarm(alarmId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            await self.manager.stopAlarm(id: Int(truncatingIfNeeded: alarmId), cancelNotif: true)
            completion(.success(()))
        }
    }

    func stopAll(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            await self.manager.stopAll()
            completion(.success(()))
        }
    }

    func isRinging(alarmId: Int64?) throws -> Bool {
        return self.manager.isRinging(id: alarmId.map { Int(truncatingIfNeeded: $0) })
    }

    func setWarningNotificationOnKill(title: String, body: String) throws {
        AppTerminateManager.shared.setWarningNotification(title: title, body: body)
    }

    func disableWarningNotificationOnKill() throws {
        throw PigeonError(
            code: String(AlarmErrorCode.pluginInternal.rawValue),
            message: "Method disableWarningNotificationOnKill not implemented.",
            details: nil)
    }

    func appRefresh() async {
        BackgroundAudioManager.shared.refresh(registrar: self.registrar)
        await self.manager.checkAlarms()
    }
}
