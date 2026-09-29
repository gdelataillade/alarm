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

        Task { @MainActor in
            await self.manager.setAlarm(alarmSettings: alarmSettings)
            completion(.success(()))
        }
    }

    func stopAlarm(alarmId: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await self.manager.stopAlarm(id: Int(truncatingIfNeeded: alarmId), cancelNotif: true)
            completion(.success(()))
        }
    }

    func stopAll(completion: @escaping (Result<Void, Error>) -> Void) {
        Task { @MainActor in
            await self.manager.stopAll()
            completion(.success(()))
        }
    }

    func isRinging(alarmId: Int64?) throws -> Bool {
        // Pigeon invokes this handler on the main thread; assumeIsolated makes
        // that explicit so the manager state can stay main-actor confined.
        return MainActor.assumeIsolated {
            self.manager.isRinging(id: alarmId.map { Int(truncatingIfNeeded: $0) })
        }
    }

    func getAlarmState(alarmId: Int64) throws -> AlarmStateWire {
        return try self.isRinging(alarmId: alarmId) ? .ringing : .inactive
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

    /// Snoozing is an Android-only capability, so there is never a marker here.
    func getPendingAlarmEvents(
        completion: @escaping (Result<[AlarmEventWire], Error>) -> Void
    ) {
        completion(.success([]))
    }

    /// No markers exist on iOS, so acknowledging one is a no-op rather than an
    /// error: Dart calls this unconditionally after applying an event.
    func acknowledgeAlarmEvent(
        alarmId: Int64,
        recordedAtMillis: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    @MainActor
    func appRefresh() async {
        BackgroundAudioManager.shared.refresh(registrar: self.registrar)
        await self.manager.checkAlarms()
    }
}
