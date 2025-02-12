import AVFoundation
import Flutter
import MediaPlayer

public class AlarmApiImpl: NSObject, AlarmApi {
    #if targetEnvironment(simulator)
        private let isDevice = false
    #else
        private let isDevice = true
    #endif

    private var registrar: FlutterPluginRegistrar!

    private var alarms: [Int: AlarmConfiguration] = [:]

    private var silentAudioPlayer: AVAudioPlayer?

    private var warningNotificationOnKill: Bool = false
    private var notificationTitleOnKill: String? = nil
    private var notificationBodyOnKill: String? = nil

    private var observerAdded = false
    private var playSilent = false
    private var previousVolume: Float? = nil

    private var vibratingAlarms: Set<Int> = []

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
    }

    func setAlarm(alarmSettings: AlarmSettingsWire) throws {
        self.mixOtherAudios()

        let alarmSettings = AlarmSettings.from(wire: alarmSettings)

        NSLog("[SwiftAlarmPlugin] AlarmSettings: \(String(describing: alarmSettings))")

        let id = alarmSettings.id

        if self.alarms.keys.contains(id) {
            NSLog("[SwiftAlarmPlugin] Stopping alarm with identical ID=\(id) before scheduling a new one.")
            self.stopAlarmInternal(id: id, cancelNotif: true)
        }

        let delayInSeconds = alarmSettings.dateTime.timeIntervalSinceNow

        NSLog("[SwiftAlarmPlugin] Alarm scheduled in \(delayInSeconds) seconds")

        let alarmConfig = AlarmConfiguration(settings: alarmSettings)

        self.alarms[id] = alarmConfig

        if delayInSeconds >= 1.0 {
            NotificationManager.shared.scheduleNotification(id: id, delayInSeconds: Int(floor(delayInSeconds)), notificationSettings: alarmSettings.notificationSettings) { error in
                if let error = error {
                    NSLog("[SwiftAlarmPlugin] Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }

        self.warningNotificationOnKill = alarmSettings.warningNotificationOnKill
        if self.warningNotificationOnKill && !self.observerAdded {
            self.observerAdded = true
            NotificationCenter.default.addObserver(self, selector: #selector(self.appWillTerminate(notification:)), name: UIApplication.willTerminateNotification, object: nil)
        }

        if let audioPlayer = self.loadAudioPlayer(withAsset: alarmSettings.assetAudioPath, forId: id) {
            let currentTime = audioPlayer.deviceCurrentTime
            let time = currentTime + delayInSeconds
            let dateTime = Date().addingTimeInterval(delayInSeconds)
            self.alarms[id]?.triggerTime = dateTime

            if alarmSettings.loopAudio {
                audioPlayer.numberOfLoops = -1
            }

            audioPlayer.prepareToPlay()

            if !self.playSilent && alarmSettings.iOSBackgroundAudio {
                self.startSilentSound()
            }

            audioPlayer.volume = 0.0
            audioPlayer.play(atTime: time + 0.5)

            self.alarms[id]?.audioPlayer = audioPlayer
            self.alarms[id]?.task = DispatchWorkItem(block: {
                self.handleAlarmAfterDelay(id: id)
            })

            self.alarms[id]?.timer?.invalidate()
            self.alarms[id]?.timer = nil
            self.alarms[id]?.timer = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
            SwiftAlarmPlugin.scheduleAppRefresh()
        } else {
            throw PigeonError(code: String(AlarmErrorCode.invalidArguments.rawValue), message: "Failed to load audio for asset: \(alarmSettings.assetAudioPath)", details: nil)
        }
    }

    func stopAlarm(alarmId: Int64) throws {
        self.stopAlarmInternal(id: Int(truncatingIfNeeded: alarmId), cancelNotif: true)
    }

    func stopAll() throws {
        NotificationManager.shared.removeAllNotifications()

        self.mixOtherAudios()

        self.vibratingAlarms.removeAll()

        if let previousVolume = self.previousVolume {
            self.setVolume(volume: previousVolume, enable: false)
        }

        let alarmIds = Array(self.alarms.keys)

        for (_, alarm) in self.alarms {
            alarm.timer?.invalidate()
            alarm.timer = nil
            alarm.task?.cancel()
            alarm.task = nil
            alarm.audioPlayer?.stop()
            alarm.audioPlayer = nil
            alarm.volumeEnforcementTimer?.invalidate()
            alarm.volumeEnforcementTimer = nil
        }
        self.alarms.removeAll()

        self.stopSilentSound()
        self.stopNotificationOnKillService()

        for id in alarmIds {
            // Inform the Flutter plugin that the alarm was stopped
            SwiftAlarmPlugin.alarmTriggerApi?.alarmStopped(alarmId: Int64(id), completion: { result in
                if case .success = result {
                    NSLog("[SwiftAlarmPlugin] Alarm stopped notification for \(id) was processed successfully by Flutter.")
                } else {
                    NSLog("[SwiftAlarmPlugin] Alarm stopped notification for \(id) encountered error in Flutter.")
                }
            })
        }
    }

    func isRinging(alarmId: Int64?) throws -> Bool {
        if let alarmId = alarmId {
            let id = Int(truncatingIfNeeded: alarmId)
            return self.alarms[id]?.triggerTime?.timeIntervalSinceNow ?? 1.0 <= 0.0
        } else {
            return self.isAnyAlarmRinging()
        }
    }

    func setWarningNotificationOnKill(title: String, body: String) throws {
        self.notificationTitleOnKill = title
        self.notificationBodyOnKill = body
    }

    func disableWarningNotificationOnKill() throws {
        throw PigeonError(code: String(AlarmErrorCode.pluginInternal.rawValue), message: "Method disableWarningNotificationOnKill not implemented", details: nil)
    }

    public func backgroundFetch() {
        self.mixOtherAudios()

        self.silentAudioPlayer?.pause()
        self.silentAudioPlayer?.play()

        let ids = Array(self.alarms.keys)

        for id in ids {
            NSLog("[SwiftAlarmPlugin] Background check alarm with id \(id)")
            if let alarm = self.alarms[id], let delayInSeconds = alarm.triggerTime?.timeIntervalSinceNow, !(alarm.timer?.isValid ?? false) {
                NSLog("[SwiftAlarmPlugin] Rescheduling alarm with id \(id)")

                // We need to make sure the existing timer is invalidated to prevent duplicate task triggers.
                alarm.timer?.invalidate()
                alarm.timer = nil
                alarm.timer = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
            }
        }
    }

    public func sendWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = self.notificationTitleOnKill ?? "Your alarms may not ring"
        content.body = self.notificationBodyOnKill ?? "You killed the app. Please reopen so your alarms can be rescheduled."

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "notification on app kill immediate", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("[SwiftAlarmPlugin] Failed to show immediate notification on app kill => error: \(error.localizedDescription)")
            } else {
                NSLog("[SwiftAlarmPlugin] Triggered immediate notification on app kill")
            }
        }
    }

    @objc private func appWillTerminate(notification: Notification) {
        self.sendWarningNotification()
    }

    // Mix with other audio sources
    func mixOtherAudios() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            NSLog("[SwiftAlarmPlugin] Error setting up audio session with option mixWithOthers: \(error.localizedDescription)")
        }
    }

    // Lower other audio sources
    private func duckOtherAudios() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            NSLog("[SwiftAlarmPlugin] Error setting up audio session with option duckOthers: \(error.localizedDescription)")
        }
    }

    private func loadAudioPlayer(withAsset assetAudio: String, forId id: Int) -> AVAudioPlayer? {
        let audioURL: URL
        if assetAudio.hasPrefix("assets/") || assetAudio.hasPrefix("asset/") {
            let filename = self.registrar.lookupKey(forAsset: assetAudio)
            guard let audioPath = Bundle.main.path(forResource: filename, ofType: nil) else {
                NSLog("[SwiftAlarmPlugin] Audio file not found: \(assetAudio)")
                return nil
            }
            audioURL = URL(fileURLWithPath: audioPath)
        } else {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            audioURL = documentsDirectory.appendingPathComponent(assetAudio)
        }

        do {
            return try AVAudioPlayer(contentsOf: audioURL)
        } catch {
            NSLog("[SwiftAlarmPlugin] Error loading audio player: \(error.localizedDescription)")
            return nil
        }
    }

    private func startSilentSound() {
        let filename = self.registrar.lookupKey(forAsset: "assets/long_blank.mp3", fromPackage: "alarm")
        if let audioPath = Bundle.main.path(forResource: filename, ofType: nil) {
            let audioUrl = URL(fileURLWithPath: audioPath)
            do {
                self.silentAudioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
                self.silentAudioPlayer?.numberOfLoops = -1
                self.silentAudioPlayer?.volume = 0.01
                self.playSilent = true
                self.silentAudioPlayer?.play()
                NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
            } catch {
                NSLog("[SwiftAlarmPlugin] Error: Could not create and play silent audio player: \(error)")
            }
        } else {
            NSLog("[SwiftAlarmPlugin] Error: Could not find silent audio file")
        }
    }

    private func isAnyAlarmRinging() -> Bool {
        for (_, alarmConfig) in self.alarms {
            if alarmConfig.triggerTime?.timeIntervalSinceNow ?? 1.0 <= 0.0 {
                return true
            }
        }
        return false
    }

    private func isAnyAlarmRingingExcept(id: Int) -> Bool {
        for (alarmId, alarmConfig) in self.alarms {
            if alarmId != id && alarmConfig.triggerTime?.timeIntervalSinceNow ?? 1.0 <= 0.0 {
                return true
            }
        }
        return false
    }

    private func handleAlarmAfterDelay(id: Int) {
        guard let alarm = self.alarms[id], let audioPlayer = alarm.audioPlayer else {
            return
        }

        if !alarm.settings.allowAlarmOverlap && self.isAnyAlarmRingingExcept(id: id) {
            NSLog("[SwiftAlarmPlugin] Ignoring alarm with id \(id) because another alarm is already ringing.")
            self.stopAlarmInternal(id: id, cancelNotif: true)
            return
        }

        self.duckOtherAudios()

        if !audioPlayer.isPlaying || audioPlayer.currentTime == 0.0 {
            audioPlayer.play()
        }

        if let triggerApi = SwiftAlarmPlugin.alarmTriggerApi {
            // Inform the Flutter plugin that the alarm rang
            triggerApi.alarmRang(alarmId: Int64(id), completion: { result in
                if case .success = result {
                    NSLog("[SwiftAlarmPlugin] Alarm rang notification for \(id) was processed successfully by Flutter.")
                } else {
                    NSLog("[SwiftAlarmPlugin] Alarm rang notification for \(id) encountered error in Flutter.")
                }
            })
        } else {
            NSLog("[SwiftAlarmPlugin] ERROR: AlarmTriggerApi was not setup!")
        }

        if alarm.settings.vibrate {
            self.vibratingAlarms.insert(id)
            if self.vibratingAlarms.count == 1 {
                self.triggerVibrations()
            }
        }

        if !alarm.settings.loopAudio {
            let audioDuration = audioPlayer.duration
            DispatchQueue.main.asyncAfter(deadline: .now() + audioDuration.toDispatchInterval()) {
                self.stopAlarmInternal(id: id, cancelNotif: false)
            }
        }

        let currentSystemVolume = self.getSystemVolume()
        let targetSystemVolume: Float

        if let volumeValue = alarm.settings.volumeSettings.volume {
            targetSystemVolume = Float(volumeValue)
            self.setVolume(volume: targetSystemVolume, enable: true)
        } else {
            targetSystemVolume = currentSystemVolume
        }

        if !alarm.settings.volumeSettings.fadeSteps.isEmpty {
            self.fadeAlarmVolumeWithSteps(id: id, steps: alarm.settings.volumeSettings.fadeSteps)
        } else if let fadeDuration = alarm.settings.volumeSettings.fadeDuration {
            self.fadeAlarmVolumeWithSteps(id: id, steps: [VolumeFadeStep(time: 0, volume: 0), VolumeFadeStep(time: fadeDuration, volume: 1.0)])
        } else {
            audioPlayer.volume = 1.0
        }

        if alarm.settings.volumeSettings.volumeEnforced {
            alarm.volumeEnforcementTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let currentSystemVolume = self.getSystemVolume()
                if abs(currentSystemVolume - targetSystemVolume) > 0.01 {
                    self.setVolume(volume: targetSystemVolume, enable: false)
                }
            }
        }
    }

    private func triggerVibrations() {
        if !self.vibratingAlarms.isEmpty && self.isDevice {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                self.triggerVibrations()
            }
        }
    }

    private func getSystemVolume() -> Float {
        let audioSession = AVAudioSession.sharedInstance()
        return audioSession.outputVolume
    }

    public func setVolume(volume: Float, enable: Bool) {
        let volumeView = MPVolumeView()

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(100)) {
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                self.previousVolume = enable ? slider.value : nil
                print("[SwiftAlarmPlugin] Setting system volume to \(volume).")
                slider.value = volume
            }
            volumeView.removeFromSuperview()
        }
    }

    private func fadeAlarmVolumeWithSteps(id: Int, steps: [VolumeFadeStep]) {
        guard let audioPlayer = self.alarms[id]?.audioPlayer else {
            return
        }

        if !audioPlayer.isPlaying {
            return
        }

        audioPlayer.volume = Float(steps[0].volume)

        let now = DispatchTime.now()

        for i in 0 ..< steps.count - 1 {
            let startTime = steps[i].time
            let nextStep = steps[i + 1]
            // Subtract 50ms to avoid weird jumps that might occur when two fades collide.
            let fadeDuration = nextStep.time - startTime - 0.05
            let targetVolume = Float(nextStep.volume)

            // Schedule the fade using setVolume for a smooth transition
            DispatchQueue.main.asyncAfter(deadline: now + startTime.toDispatchInterval()) {
                if !audioPlayer.isPlaying {
                    return
                }
                print("[SwiftAlarmPlugin] Fading volume to \(targetVolume) over \(fadeDuration) seconds.")
                audioPlayer.setVolume(targetVolume, fadeDuration: fadeDuration)
            }
        }
    }

    private func stopAlarmInternal(id: Int, cancelNotif: Bool) {
        if cancelNotif {
            NotificationManager.shared.cancelNotification(id: id)
        }
        NotificationManager.shared.dismissNotification(id: id)

        self.mixOtherAudios()

        self.vibratingAlarms.remove(id)

        if let previousVolume = self.previousVolume {
            self.setVolume(volume: previousVolume, enable: false)
        }

        if let alarm = self.alarms[id] {
            alarm.timer?.invalidate()
            alarm.timer = nil
            alarm.task?.cancel()
            alarm.task = nil
            alarm.audioPlayer?.stop()
            alarm.audioPlayer = nil
            alarm.volumeEnforcementTimer?.invalidate()
            alarm.volumeEnforcementTimer = nil
            self.alarms.removeValue(forKey: id)
        }

        self.stopSilentSound()
        self.stopNotificationOnKillService()

        // Inform the Flutter plugin that the alarm was stopped
        SwiftAlarmPlugin.alarmTriggerApi?.alarmStopped(alarmId: Int64(id), completion: { result in
            if case .success = result {
                NSLog("[SwiftAlarmPlugin] Alarm stopped notification for \(id) was processed successfully by Flutter.")
            } else {
                NSLog("[SwiftAlarmPlugin] Alarm stopped notification for \(id) encountered error in Flutter.")
            }
        })
    }

    private func stopSilentSound() {
        self.mixOtherAudios()

        if self.alarms.isEmpty {
            self.playSilent = false
            self.silentAudioPlayer?.stop()
            NotificationCenter.default.removeObserver(self)
            SwiftAlarmPlugin.cancelBackgroundTasks()
        }
    }

    private func stopNotificationOnKillService() {
        if self.alarms.isEmpty && self.observerAdded {
            NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
            self.observerAdded = false
        }
    }

    @objc func executeTask(_ timer: Timer) {
        if let id = timer.userInfo as? Int, let task = alarms[id]?.task, !task.isCancelled {
            task.perform()
        }
    }

    @objc func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        switch type {
            case .began:
                self.silentAudioPlayer?.play()
                NSLog("[SwiftAlarmPlugin] Interruption began")
            case .ended:
                self.silentAudioPlayer?.play()
                NSLog("[SwiftAlarmPlugin] Interruption ended")
            default:
                break
        }
    }
}

extension TimeInterval {
    func toDispatchInterval() -> DispatchTimeInterval {
        return DispatchTimeInterval.milliseconds(Int(self * 1_000))
    }
}
