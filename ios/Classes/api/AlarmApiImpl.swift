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

    func setAlarm(alarmSettings: AlarmSettingsWire) throws {
        let alarmSettings = AlarmSettings.from(wire: alarmSettings)
        os_log(.info, log: AlarmApiImpl.logger, "AlarmSettings: %@", String(describing: alarmSettings))

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await self.manager.setAlarm(alarmSettings: alarmSettings)
            semaphore.signal()
        }
        semaphore.wait()
    }

    func stopAlarm(alarmId: Int64) throws {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await self.manager.stopAlarm(id: Int(truncatingIfNeeded: alarmId), cancelNotif: true)
            semaphore.signal()
        }
        semaphore.wait()
    }

    func stopAll() {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await self.manager.stopAll()
            semaphore.signal()
        }
        semaphore.wait()
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

    func appRefresh() {
        BackgroundAudioManager.shared.refresh(registrar: self.registrar)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await self.manager.checkAlarms()
            semaphore.signal()
        }
        semaphore.wait()
    }
}
