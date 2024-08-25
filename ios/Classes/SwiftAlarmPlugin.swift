import Flutter
import UIKit
import AVFoundation
import AudioToolbox
import MediaPlayer
import BackgroundTasks

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
    #if targetEnvironment(simulator)
        private let isDevice = false
    #else
        private let isDevice = true
    #endif

    private var registrar: FlutterPluginRegistrar!
    static let shared = SwiftAlarmPlugin()
    static let backgroundTaskIdentifier: String = "com.gdelataillade.fetch"
    private var channel: FlutterMethodChannel!

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.gdelataillade/alarm", binaryMessenger: registrar.messenger())
        let instance = SwiftAlarmPlugin.shared

        instance.channel = channel
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var alarms: [Int: AlarmConfiguration] = [:]

    private var silentAudioPlayer: AVAudioPlayer?
    private let resourceAccessQueue = DispatchQueue(label: "com.gdelataillade.alarm.resourceAccessQueue")

    private var notifOnKillEnabled: Bool = false
    private var notificationTitleOnKill: String? = nil
    private var notificationBodyOnKill: String? = nil

    private var observerAdded = false
    private var vibrate = false
    private var playSilent = false
    private var previousVolume: Float? = nil

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .default).async {
            switch call.method {
            case "setAlarm":
                self.setAlarm(call: call, result: result)
            case "stopAlarm":
                guard let args = call.arguments as? [String: Any], let id = args["id"] as? Int else {
                    result(FlutterError(code: "NATIVE_ERR", message: "[SwiftAlarmPlugin] Error: id parameter is missing or invalid", details: nil))
                    return
                }
                self.stopAlarm(id: id, cancelNotif: true, result: result)
            case "audioCurrentTime":
                guard let args = call.arguments as? [String: Any], let id = args["id"] as? Int else {
                    result(FlutterError(code: "NATIVE_ERR", message: "[SwiftAlarmPlugin] Error: id parameter is missing or invalid for audioCurrentTime", details: nil))
                    return
                }
                self.audioCurrentTime(id: id, result: result)
            case "setNotificationOnAppKillContent":
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "NATIVE_ERR", message: "[SwiftAlarmPlugin] Error: Arguments are not in the expected format for setNotificationOnAppKillContent", details: nil))
                    return
                }
                self.notificationTitleOnKill = (args["notifTitleOnAppKill"] as! String)
                self.notificationBodyOnKill = (args["notifDescriptionOnAppKill"] as! String)
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func stopAlarmFromNotification(id: Int) {
        AlarmStorage.shared.unsaveAlarm(id: id)
        safeModifyResources {
            self.stopAlarm(id: id, cancelNotif: true, result: { _ in })
        }
        NSLog("SwiftAlarmPlugin: stopAlarmFromNotification...")
        channel.invokeMethod("alarmStoppedFromNotification", arguments: ["id": id])
    }

    func safeModifyResources(_ modificationBlock: @escaping () -> Void) {
        resourceAccessQueue.async {
            modificationBlock()
        }
    }

    private func setAlarm(call: FlutterMethodCall, result: FlutterResult) {
        self.mixOtherAudios()

        guard let args = call.arguments as? [String: Any],
            let alarmSettings = AlarmSettings.fromJson(json: args) else {
            let argumentsDescription = "\(call.arguments ?? "nil")"
            result(FlutterError(code: "NATIVE_ERR", message: "[SwiftAlarmPlugin] Arguments are not in the expected format: \(argumentsDescription)", details: nil))
            return
        }

        NSLog("SwiftAlarmPlugin: AlarmSettings: \(alarmSettings)")

        var volumeFloat: Float? = nil
        if let volumeValue = alarmSettings.volume {
            volumeFloat = Float(volumeValue)
        }

        let id = alarmSettings.id
        let delayInSeconds = alarmSettings.dateTime.timeIntervalSinceNow

        NSLog("SwiftAlarmPlugin: Alarm scheduled in \(delayInSeconds) seconds")

        let alarmConfig = AlarmConfiguration(
            id: id,
            assetAudio: alarmSettings.assetAudioPath,
            vibrationsEnabled: alarmSettings.vibrate,
            loopAudio: alarmSettings.loopAudio,
            fadeDuration: alarmSettings.fadeDuration,
            volume: volumeFloat
        )
        self.alarms[id] = alarmConfig

        let notificationTitle = args["notificationTitle"] as? String
        let notificationBody = args["notificationBody"] as? String
        if let title = notificationTitle, let body = notificationBody, delayInSeconds >= 1.0 {
            NotificationManager.shared.scheduleNotification(id: id, delayInSeconds: Int(floor(delayInSeconds)), title: title, body: body, actionSettings: alarmSettings.notificationActionSettings) { error in
                if let error = error {
                    NSLog("[SwiftAlarmPlugin] Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }

        notifOnKillEnabled = (args["enableNotificationOnKill"] as! Bool)
        if notifOnKillEnabled && !observerAdded {
            observerAdded = true
            NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        }

        // Load audio player with given asset
        if let audioPlayer = self.loadAudioPlayer(withAsset: alarmSettings.assetAudioPath, forId: id) {
            safeModifyResources {
                let currentTime = audioPlayer.deviceCurrentTime
                let time = currentTime + delayInSeconds
                let dateTime = Date().addingTimeInterval(delayInSeconds)

                if alarmSettings.loopAudio {
                    audioPlayer.numberOfLoops = -1
                }

                audioPlayer.prepareToPlay()

                if alarmSettings.fadeDuration > 0.0 {
                    audioPlayer.volume = 0.01
                }

                if !self.playSilent {
                    self.startSilentSound()
                }

                audioPlayer.play(atTime: time + 0.5)

                self.alarms[id]?.audioPlayer = audioPlayer
                self.alarms[id]?.triggerTime = dateTime
                self.alarms[id]?.task = DispatchWorkItem(block: {
                    self.handleAlarmAfterDelay(id: id)
                })

                DispatchQueue.main.async {
                    self.alarms[id]?.timer = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
                }
                SwiftAlarmPlugin.scheduleAppRefresh()
            }
            result(true)
        } else {
            result(FlutterError(code: "NATIVE_ERR", message: "[SwiftAlarmPlugin] Failed to load audio for asset: \(alarmSettings.assetAudioPath)", details: nil))
            return
        }
    }

    private func loadAudioPlayer(withAsset assetAudio: String, forId id: Int) -> AVAudioPlayer? {
        let audioURL: URL
        if assetAudio.hasPrefix("assets/") || assetAudio.hasPrefix("asset/") {
            // Load audio from assets
            let filename = registrar.lookupKey(forAsset: assetAudio)
            guard let audioPath = Bundle.main.path(forResource: filename, ofType: nil) else {
                NSLog("[SwiftAlarmPlugin] Audio file not found: \(assetAudio)")
                return nil
            }
            audioURL = URL(fileURLWithPath: audioPath)
        } else {
            // Load audio from documents directory
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

    @objc func executeTask(_ timer: Timer) {
        if let id = timer.userInfo as? Int, let task = alarms[id]?.task {
            task.perform()
        }
    }

    private func startSilentSound() {
        let filename = registrar.lookupKey(forAsset: "assets/long_blank.mp3", fromPackage: "alarm")
        if let audioPath = Bundle.main.path(forResource: filename, ofType: nil) {
            let audioUrl = URL(fileURLWithPath: audioPath)
            do {
                self.silentAudioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
                self.silentAudioPlayer?.numberOfLoops = -1
                self.silentAudioPlayer?.volume = 0.1
                self.playSilent = true
                self.silentAudioPlayer?.play()
                NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
            } catch {
                NSLog("[SwiftAlarmPlugin] Error: Could not create and play silent audio player: \(error)")
            }
        } else {
            NSLog("[SwiftAlarmPlugin] Error: Could not find silent audio file")
        }
    }

    @objc func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
            case .began:
                self.silentAudioPlayer?.play()
                NSLog("SwiftAlarmPlugin: Interruption began")
            case .ended:
                self.silentAudioPlayer?.play()
                NSLog("SwiftAlarmPlugin: Interruption ended")
            default:
                break
            }
    }

    private func loopSilentSound() {
        self.silentAudioPlayer?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.silentAudioPlayer?.pause()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if self.playSilent {
                    self.loopSilentSound()
                }
            }
        }
    }

    private func handleAlarmAfterDelay(id: Int) {
        safeModifyResources {
            guard let alarm = self.alarms[id], let audioPlayer = alarm.audioPlayer else {
                return
            }

            DispatchQueue.main.async {
                self.duckOtherAudios()

                if !audioPlayer.isPlaying || audioPlayer.currentTime == 0.0 {
                    audioPlayer.play()
                }

                self.vibrate = alarm.vibrationsEnabled
                self.triggerVibrations()

                if !alarm.loopAudio {
                    let audioDuration = audioPlayer.duration
                    DispatchQueue.main.asyncAfter(deadline: .now() + audioDuration) {
                        self.stopAlarm(id: id, cancelNotif: false, result: { _ in })
                    }
                }

                if let volumeValue = alarm.volume {
                    self.setVolume(volume: volumeValue, enable: true)
                }

                if alarm.fadeDuration > 0.0 {
                    audioPlayer.setVolume(1.0, fadeDuration: alarm.fadeDuration)
                }
            }
        }
    }

    private func stopAlarm(id: Int, cancelNotif: Bool, result: FlutterResult) {
        if cancelNotif {
            NotificationManager.shared.cancelNotification(id: id)
        }

        self.mixOtherAudios()

        self.vibrate = false

        safeModifyResources {
            // Restore the previous volume if it was saved
            if let previousVolume = self.previousVolume {
                self.setVolume(volume: previousVolume, enable: false)
            }

            // Clean up all alarm related resources
            if let alarm = self.alarms[id] {
                alarm.timer?.invalidate()
                alarm.task?.cancel()
                alarm.audioPlayer?.stop()
                self.alarms.removeValue(forKey: id)
            }
        }

        self.stopSilentSound()
        self.stopNotificationOnKillService()

        result(true)
    }

    private func stopSilentSound() {
        self.mixOtherAudios()

        safeModifyResources {
            if self.alarms.isEmpty {
                self.playSilent = false
                DispatchQueue.main.async {
                    self.silentAudioPlayer?.stop()
                    NotificationCenter.default.removeObserver(self)
                    SwiftAlarmPlugin.cancelBackgroundTasks()
                }
            }
        }
    }

    private func triggerVibrations() {
        if vibrate && isDevice {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    AudioServicesDisposeSystemSoundID(kSystemSoundID_Vibrate)
                    self.triggerVibrations()
                }
        }
    }

    public func setVolume(volume: Float, enable: Bool) {
        DispatchQueue.main.async {
            let volumeView = MPVolumeView()

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                    self.previousVolume = enable ? slider.value : nil
                    slider.value = volume
                }
                volumeView.removeFromSuperview()
            }
        }
    }

    private func audioCurrentTime(id: Int, result: FlutterResult) {
        if let audioPlayer = self.alarms[id]?.audioPlayer {
            let time = Double(audioPlayer.currentTime)
            result(time)
        } else {
            result(0.0)
        }
    }

    private func backgroundFetch() {
        self.mixOtherAudios()

        self.silentAudioPlayer?.pause()
        self.silentAudioPlayer?.play()

        safeModifyResources {
            let ids = Array(self.alarms.keys)

            for id in ids {
                NSLog("SwiftAlarmPlugin: Background check alarm with id \(id)")
                if let audioPlayer = self.alarms[id]?.audioPlayer, let dateTime = self.alarms[id]?.triggerTime {
                    let currentTime = audioPlayer.deviceCurrentTime
                    let time = currentTime + dateTime.timeIntervalSinceNow
                    audioPlayer.play(atTime: time)
                }

                if let alarm = self.alarms[id], let delayInSeconds = alarm.triggerTime?.timeIntervalSinceNow {
                    DispatchQueue.main.async {
                        self.safeModifyResources {
                            alarm.timer = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
                        }
                    }
                }
            }
        }
    }

    private func stopNotificationOnKillService() {
        safeModifyResources {
            if self.alarms.isEmpty && self.observerAdded {
                NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
                self.observerAdded = false
            }
        }
    }

    // Show notification on app kill
    @objc func applicationWillTerminate(_ notification: Notification) {
        let content = UNMutableNotificationContent()
        content.title = notificationTitleOnKill ?? "Your alarms may not ring"
        content.body = notificationBodyOnKill ?? "You killed the app. Please reopen so your alarms can be rescheduled."

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "notification on app kill immediate", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                NSLog("SwiftAlarmPlugin: Failed to show immediate notification on app kill => error: \(error.localizedDescription)")
            } else {
                NSLog("SwiftAlarmPlugin: Triggered immediate notification on app kill")
            }
        }
    }

    // Mix with other audio sources
    private func mixOtherAudios() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            NSLog("SwiftAlarmPlugin: Error setting up audio session with option mixWithOthers: \(error.localizedDescription)")
        }
    }

    // Lower other audio sources
    private func duckOtherAudios() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            NSLog("SwiftAlarmPlugin: Error setting up audio session with option duckOthers: \(error.localizedDescription)")
        }
    }

    /// Runs from AppDelegate when the app is launched
    static public func registerBackgroundTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                self.scheduleAppRefresh()
                shared.backgroundFetch()
                task.setTaskCompleted(success: true)
            }
        } else {
            NSLog("SwiftAlarmPlugin: BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }

    /// Enables background fetch
    static func scheduleAppRefresh() {
        if #available(iOS 13.0, *) {
            let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)

            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                NSLog("SwiftAlarmPlugin: Could not schedule app refresh: \(error)")
            }
        } else {
            NSLog("SwiftAlarmPlugin: BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }

    /// Disables background fetch
    static func cancelBackgroundTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        } else {
            NSLog("SwiftAlarmPlugin: BGTaskScheduler not available for your version of iOS lower than 13.0")
        }
    }
}
