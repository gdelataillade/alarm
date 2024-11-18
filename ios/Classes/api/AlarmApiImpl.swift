import AVFoundation
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

        var volumeFloat: Float? = nil
        if let volumeValue = alarmSettings.volume {
            volumeFloat = Float(volumeValue)
        }

        let id = alarmSettings.id
        let delayInSeconds = alarmSettings.dateTime.timeIntervalSinceNow

        NSLog("[SwiftAlarmPlugin] Alarm scheduled in \(delayInSeconds) seconds")

        let alarmConfig = AlarmConfiguration(
            id: id,
            assetAudio: alarmSettings.assetAudioPath,
            vibrationsEnabled: alarmSettings.vibrate,
            loopAudio: alarmSettings.loopAudio,
            fadeDuration: alarmSettings.fadeDuration,
            volume: volumeFloat,
            volumeEnforced: alarmSettings.volumeEnforced
        )

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

            if alarmSettings.loopAudio {
                audioPlayer.numberOfLoops = -1
            }

            audioPlayer.prepareToPlay()

            if !self.playSilent {
                self.startSilentSound()
            }

            audioPlayer.play(atTime: time + 0.5)

            self.alarms[id]?.audioPlayer = audioPlayer
            self.alarms[id]?.triggerTime = dateTime
            self.alarms[id]?.task = DispatchWorkItem(block: {
                self.handleAlarmAfterDelay(id: id)
            })

            self.alarms[id]?.timer = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
            SwiftAlarmPlugin.scheduleAppRefresh()
        } else {
            throw PigeonError(code: String(AlarmErrorCode.invalidArguments.rawValue), message: "Failed to load audio for asset: \(alarmSettings.assetAudioPath)", details: nil)
        }
    }

    func stopAlarm(alarmId: Int64) throws {
        self.stopAlarmInternal(id: Int(truncatingIfNeeded: alarmId), cancelNotif: true)
    }

    func isRinging(alarmId: Int64?) throws -> Bool {
        if let alarmId = alarmId {
            let id = Int(truncatingIfNeeded: alarmId)
            let isPlaying = self.alarms[id]?.audioPlayer?.isPlaying ?? false
            let currentTime = self.alarms[id]?.audioPlayer?.currentTime ?? 0.0
            return isPlaying && currentTime > 0
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

    public func unsaveAlarm(id: Int) {
        AlarmStorage.shared.unsaveAlarm(id: id)
        self.stopAlarmInternal(id: id, cancelNotif: true)
    }

    public func backgroundFetch() {
        self.mixOtherAudios()

        self.silentAudioPlayer?.pause()
        self.silentAudioPlayer?.play()

        let ids = Array(self.alarms.keys)

        for id in ids {
            NSLog("[SwiftAlarmPlugin] Background check alarm with id \(id)")
            if let audioPlayer = self.alarms[id]?.audioPlayer, let dateTime = self.alarms[id]?.triggerTime {
                let currentTime = audioPlayer.deviceCurrentTime
                let time = currentTime + dateTime.timeIntervalSinceNow
                audioPlayer.play(atTime: time)
            }

            if let alarm = self.alarms[id], let delayInSeconds = alarm.triggerTime?.timeIntervalSinceNow {
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
                self.silentAudioPlayer?.volume = 0.1
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
            if let audioPlayer = alarmConfig.audioPlayer, audioPlayer.isPlaying, audioPlayer.currentTime > 0 {
                return true
            }
        }
        return false
    }

    private func handleAlarmAfterDelay(id: Int) {
        if self.isAnyAlarmRinging() {
            NSLog("[SwiftAlarmPlugin] Ignoring alarm with id \(id) because another alarm is already ringing.")
            self.unsaveAlarm(id: id)
            return
        }

        guard let alarm = self.alarms[id], let audioPlayer = alarm.audioPlayer else {
            return
        }

        self.duckOtherAudios()

        if !audioPlayer.isPlaying || audioPlayer.currentTime == 0.0 {
            audioPlayer.play()
        }

        if alarm.vibrationsEnabled {
            self.vibratingAlarms.insert(id)
            if self.vibratingAlarms.count == 1 {
                self.triggerVibrations()
            }
        }

        if !alarm.loopAudio {
            let audioDuration = audioPlayer.duration
            DispatchQueue.main.asyncAfter(deadline: .now() + audioDuration) {
                self.stopAlarmInternal(id: id, cancelNotif: false)
            }
        }

        let currentSystemVolume = self.getSystemVolume()
        let targetSystemVolume: Float

        if let volumeValue = alarm.volume {
            targetSystemVolume = volumeValue
            self.setVolume(volume: targetSystemVolume, enable: true)
        } else {
            targetSystemVolume = currentSystemVolume
        }

        if alarm.fadeDuration > 0.0 {
            audioPlayer.volume = 0.01
            self.fadeVolume(audioPlayer: audioPlayer, duration: alarm.fadeDuration)
        } else {
            audioPlayer.volume = 1.0
        }

        if alarm.volumeEnforced {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                self.previousVolume = enable ? slider.value : nil
                slider.value = volume
            }
            volumeView.removeFromSuperview()
        }
    }

    private func fadeVolume(audioPlayer: AVAudioPlayer, duration: TimeInterval) {
        let fadeInterval: TimeInterval = 0.2
        let currentVolume = audioPlayer.volume
        let volumeDifference = 1.0 - currentVolume
        let steps = Int(duration / fadeInterval)
        let volumeIncrement = volumeDifference / Float(steps)

        var currentStep = 0
        Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { timer in
            if !audioPlayer.isPlaying {
                timer.invalidate()
                NSLog("[SwiftAlarmPlugin] Volume fading stopped as audioPlayer is no longer playing.")
                return
            }

            NSLog("[SwiftAlarmPlugin] Fading volume: \(100 * currentStep / steps)%%")
            if currentStep >= steps {
                timer.invalidate()
                audioPlayer.volume = 1.0
            } else {
                audioPlayer.volume += volumeIncrement
                currentStep += 1
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
            alarm.task?.cancel()
            alarm.audioPlayer?.stop()
            alarm.volumeEnforcementTimer?.invalidate()
            self.alarms.removeValue(forKey: id)
        }

        self.stopSilentSound()
        self.stopNotificationOnKillService()
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
        if let id = timer.userInfo as? Int, let task = alarms[id]?.task {
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
