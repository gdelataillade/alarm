import Flutter
import os.log

class AlarmManager: NSObject {
    private static let logger = OSLog(subsystem: ALARM_BUNDLE, category: "AlarmManager")

    private let registrar: FlutterPluginRegistrar

    private var alarms: [Int: AlarmConfiguration] = [:]

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    func setAlarm(alarmSettings: AlarmSettings) async {
        if self.alarms.keys.contains(alarmSettings.id) {
            os_log(.info, log: AlarmManager.logger, "Stopping alarm with identical ID=%d before scheduling a new one.", alarmSettings.id)
            await self.stopAlarm(id: alarmSettings.id, cancelNotif: true)
        }

        let config = AlarmConfiguration(settings: alarmSettings)
        self.alarms[alarmSettings.id] = config

        let delayInSeconds = alarmSettings.dateTime.timeIntervalSinceNow
        if delayInSeconds < 1 {
            Task {
                if delayInSeconds > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
                }
                await self.ringAlarm(id: alarmSettings.id)
            }
        } else {
            let timer = Timer(timeInterval: delayInSeconds,
                              target: self,
                              selector: #selector(self.alarmTimerTrigerred(_:)),
                              userInfo: alarmSettings.id,
                              repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            config.timer = timer
        }

        self.updateState()

        os_log(.info, log: AlarmManager.logger, "Set alarm for ID=%d complete.", alarmSettings.id)
    }

    func stopAlarm(id: Int, cancelNotif: Bool) async {
        if cancelNotif {
            NotificationManager.shared.cancelNotification(id: id)
        }
        NotificationManager.shared.dismissNotification(id: id)

        await AlarmRingManager.shared.stop()

        if let config = self.alarms[id] {
            config.timer?.invalidate()
            config.timer = nil
            self.alarms.removeValue(forKey: id)
        }

        self.updateState()

        await self.notifyAlarmStopped(id: id)

        os_log(.info, log: AlarmManager.logger, "Stop alarm for ID=%d complete.", id)
    }

    func stopAll() async {
        await NotificationManager.shared.removeAllNotifications()

        await AlarmRingManager.shared.stop()

        let alarmIds = Array(self.alarms.keys)
        self.alarms.forEach { $0.value.timer?.invalidate() }
        self.alarms.removeAll()

        self.updateState()

        for alarmId in alarmIds {
            await self.notifyAlarmStopped(id: alarmId)
        }

        os_log(.info, log: AlarmManager.logger, "Stop all complete.")
    }

    func isRinging(id: Int? = nil) -> Bool {
        guard let alarmId = id else {
            return self.alarms.values.contains(where: { $0.state == .ringing })
        }
        return self.alarms[alarmId]?.state == .ringing
    }

    /// Ensures all alarm timers are valid and reschedules them if not.
    func checkAlarms() async {
        var rescheduled = 0
        for (id, config) in self.alarms {
            if config.state == .ringing || config.timer?.isValid ?? false {
                continue
            }

            rescheduled += 1

            config.timer?.invalidate()
            config.timer = nil

            let delayInSeconds = config.settings.dateTime.timeIntervalSinceNow
            if delayInSeconds <= 0 {
                await self.ringAlarm(id: id)
                continue
            }
            if delayInSeconds < 1 {
                try? await Task.sleep(nanoseconds: UInt64(delayInSeconds * 1_000_000_000))
                await self.ringAlarm(id: id)
                continue
            }

            let timer = Timer(timeInterval: delayInSeconds,
                              target: self,
                              selector: #selector(self.alarmTimerTrigerred(_:)),
                              userInfo: config.settings.id,
                              repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            config.timer = timer
        }

        os_log(.info, log: AlarmManager.logger, "Check alarms complete. Rescheduled %d timers.", rescheduled)
    }

    @objc private func alarmTimerTrigerred(_ timer: Timer) {
        guard let alarmId = timer.userInfo as? Int else {
            os_log(.error, log: AlarmManager.logger, "Alarm timer had invalid userInfo: %@", String(describing: timer.userInfo))
            return
        }
        Task {
            await self.ringAlarm(id: alarmId)
        }
    }

    private func ringAlarm(id: Int) async {
        guard let config = self.alarms[id] else {
            os_log(.error, log: AlarmManager.logger, "Alarm %d was not found and cannot be rung.", id)
            return
        }

        if !config.settings.allowAlarmOverlap && self.alarms.contains(where: { $1.state == .ringing }) {
            os_log(.error, log: AlarmManager.logger, "Ignoring alarm with id %d because another alarm is already ringing.", id)
            await self.stopAlarm(id: id, cancelNotif: true)
            return
        }

        if config.state == .ringing {
            os_log(.error, log: AlarmManager.logger, "Alarm %d is already ringing.", id)
            return
        }

        config.state = .ringing
        config.timer?.invalidate()
        config.timer = nil

        await NotificationManager.shared.showNotification(id: config.settings.id, notificationSettings: config.settings.notificationSettings)

        await AlarmRingManager.shared.start(
            registrar: self.registrar,
            assetAudioPath: config.settings.assetAudioPath,
            loopAudio: config.settings.loopAudio,
            volumeSettings: config.settings.volumeSettings,
            onComplete: config.settings.loopAudio ? { [weak self] in
                Task {
                    await self?.stopAlarm(id: id, cancelNotif: false)
                }
            } : nil)

        self.updateState()

        await self.notifyAlarmRang(id: id)

        os_log(.info, log: AlarmManager.logger, "Ring alarm for ID=%d complete.", id)
    }

    @MainActor
    private func notifyAlarmRang(id: Int) async {
        await withCheckedContinuation { continuation in
            guard let triggerApi = SwiftAlarmPlugin.getTriggerApi() else {
                os_log(.error, log: AlarmManager.logger, "AlarmTriggerApi.alarmRang was not setup!")
                continuation.resume()
                return
            }

            os_log(.info, log: AlarmManager.logger, "Informing the Flutter plugin that alarm %d has rang...", id)

            triggerApi.alarmRang(alarmId: Int64(id), completion: { result in
                if case .success = result {
                    os_log(.info, log: AlarmManager.logger, "Alarm rang notification for %d was processed successfully by Flutter.", id)
                } else {
                    os_log(.info, log: AlarmManager.logger, "Alarm rang notification for %d encountered error in Flutter.", id)
                }
                continuation.resume()
            })
        }
    }

    @MainActor
    private func notifyAlarmStopped(id: Int) async {
        await withCheckedContinuation { continuation in
            guard let triggerApi = SwiftAlarmPlugin.getTriggerApi() else {
                os_log(.error, log: AlarmManager.logger, "AlarmTriggerApi.alarmStopped was not setup!")
                continuation.resume()
                return
            }

            os_log(.info, log: AlarmManager.logger, "Informing the Flutter plugin that alarm %d has stopped...", id)

            triggerApi.alarmStopped(alarmId: Int64(id), completion: { result in
                if case .success = result {
                    os_log(.info, log: AlarmManager.logger, "Alarm stopped notification for %d was processed successfully by Flutter.", id)
                } else {
                    os_log(.info, log: AlarmManager.logger, "Alarm stopped notification for %d encountered error in Flutter.", id)
                }
                continuation.resume()
            })
        }
    }

    private func updateState() {
        if self.alarms.contains(where: { $1.state == .scheduled && $1.settings.warningNotificationOnKill }) {
            AppTerminateManager.shared.startMonitoring()
        } else {
            AppTerminateManager.shared.stopMonitoring()
        }

        if !self.alarms.contains(where: { $1.state == .ringing }) && self.alarms.contains(where: { $1.state == .scheduled && $1.settings.iOSBackgroundAudio }) {
            BackgroundAudioManager.shared.start(registrar: self.registrar)
        } else {
            BackgroundAudioManager.shared.stop()
        }

        if self.alarms.contains(where: { $1.state == .scheduled }) {
            BackgroundTaskManager.enable()
        } else {
            BackgroundTaskManager.disable()
        }

        if self.alarms.contains(where: { $1.state == .ringing && $1.settings.vibrate }) {
            VibrationManager.shared.start()
        } else {
            VibrationManager.shared.stop()
        }

        os_log(.debug, log: AlarmManager.logger, "State updated.")
    }
}
