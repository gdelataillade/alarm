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
    static let sharedInstance = SwiftAlarmPlugin()
    static let backgroundTaskIdentifier: String = "com.gdelataillade.fetch"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.gdelataillade/alarm", binaryMessenger: registrar.messenger())
        let instance = SwiftAlarmPlugin()

        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var audioPlayers: [Int: AVAudioPlayer] = [:]
    private var silentAudioPlayer: AVAudioPlayer?
    private var tasksQueue: [Int: DispatchWorkItem] = [:]
    private var timers: [Int: Timer] = [:]
    private var triggerTimes: [Int: Date] = [:]

    private var notifOnKillEnabled: Bool!
    private var notificationTitleOnKill: String!
    private var notificationBodyOnKill: String!

    private var observerAdded = false
    private var vibrate = false
    private var playSilent = false
    private var previousVolume: Float? = nil

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .default).async {
            if call.method == "setAlarm" {
                self.setAlarm(call: call, result: result)
            } else if call.method == "stopAlarm" {
                if let args = call.arguments as? [String: Any], let id = args["id"] as? Int {
                    self.stopAlarm(id: id, result: result)
                } else {
                    result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error: id parameter is missing or invalid", details: nil))
                }
            } else if call.method == "audioCurrentTime" {
                let args = call.arguments as! Dictionary<String, Any>
                let id = args["id"] as! Int
                self.audioCurrentTime(id: id, result: result)
            } else {
                DispatchQueue.main.sync {
                    result(FlutterMethodNotImplemented)
                }
            }
        }
    }

    private func setAlarm(call: FlutterMethodCall, result: FlutterResult) {
        self.mixOtherAudios()

        let args = call.arguments as! Dictionary<String, Any>

        let id = args["id"] as! Int
        let delayInSeconds = args["delayInSeconds"] as! Double
        let notificationTitle = args["notificationTitle"] as? String
        let notificationBody = args["notificationBody"] as? String

        if (notificationTitle != nil && notificationBody != nil && delayInSeconds >= 1.0) {
            self.scheduleNotification(id: String(id), delayInSeconds: Int(floor(delayInSeconds)), title: notificationTitle!, body: notificationBody!)
        }

        notifOnKillEnabled = (args["notifOnKillEnabled"] as! Bool)
        notificationTitleOnKill = (args["notifTitleOnAppKill"] as! String)
        notificationBodyOnKill = (args["notifDescriptionOnAppKill"] as! String)

        if notifOnKillEnabled && !observerAdded {
            observerAdded = true
            NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        }

        let loopAudio = args["loopAudio"] as! Bool
        let fadeDuration = args["fadeDuration"] as! Double
        let vibrationsEnabled = args["vibrate"] as! Bool
        let volume = args["volume"] as? Double
        let assetAudio = args["assetAudio"] as! String

        var volumeFloat: Float? = nil
        if let volumeValue = volume {
            volumeFloat = Float(volumeValue)
        }

        if assetAudio.hasPrefix("assets/") {
            let filename = registrar.lookupKey(forAsset: assetAudio)

            if let audioPath = Bundle.main.path(forResource: filename, ofType: nil) {
                let audioUrl = URL(fileURLWithPath: audioPath)
                do {
                    let audioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
                    self.audioPlayers[id] = audioPlayer
                } catch {
                    result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error loading AVAudioPlayer with given Flutter asset path: \(assetAudio)", details: nil))
                    return
                }
            } else {
                result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error finding audio file: \(assetAudio)", details: nil))
                return
            }
        } else {
            do {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let filename = String(assetAudio.split(separator: "/").last ?? "")
                let assetAudioURL = documentsDirectory.appendingPathComponent(filename)

                let audioPlayer = try AVAudioPlayer(contentsOf: assetAudioURL)
                self.audioPlayers[id] = audioPlayer
            } catch {
                result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error loading given local asset path: \(assetAudio)", details: nil))
                return
            }
        }

        let currentTime = self.audioPlayers[id]!.deviceCurrentTime
        let time = currentTime + delayInSeconds

        let dateTime = Date().addingTimeInterval(delayInSeconds)
        self.triggerTimes[id] = dateTime

        if loopAudio {
            self.audioPlayers[id]!.numberOfLoops = -1
        }

        self.audioPlayers[id]!.prepareToPlay()

        if fadeDuration > 0.0 {
            self.audioPlayers[id]!.volume = 0.1
        }

        if !playSilent {
            self.startSilentSound()
        }

        self.audioPlayers[id]!.play(atTime: time)

        self.tasksQueue[id] = DispatchWorkItem(block: {
            self.handleAlarmAfterDelay(
                id: id,
                triggerTime: dateTime,
                fadeDuration: fadeDuration,
                vibrationsEnabled: vibrationsEnabled,
                audioLoop: loopAudio,
                volume: volumeFloat
            )
        })

        DispatchQueue.main.async {
            self.timers[id] = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
            SwiftAlarmPlugin.scheduleAppRefresh()
        }

        result(true)
    }

    @objc func executeTask(_ timer: Timer) {
        if let taskId = timer.userInfo as? Int, let task = tasksQueue[taskId] {
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
                NSLog("SwiftAlarmPlugin: Error: Could not create and play audio player: \(error)")
            }
        } else {
            NSLog("SwiftAlarmPlugin: Error: Could not find audio file")
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

    private func handleAlarmAfterDelay(id: Int, triggerTime: Date, fadeDuration: Double, vibrationsEnabled: Bool, audioLoop: Bool, volume: Float?) {
        guard let audioPlayer = self.audioPlayers[id], let storedTriggerTime = triggerTimes[id], triggerTime == storedTriggerTime else {
            return
        }

        self.duckOtherAudios()

        if !audioPlayer.isPlaying || audioPlayer.currentTime == 0.0 {
            self.audioPlayers[id]!.play()
        }

        self.vibrate = vibrationsEnabled
        self.triggerVibrations()

        if !audioLoop {
            let audioDuration = audioPlayer.duration
            DispatchQueue.main.asyncAfter(deadline: .now() + audioDuration) {
                self.vibrate = false
            }
        }

        if let volumeValue = volume {  
            self.setVolume(volume: volumeValue, enable: true)  
        }
        if fadeDuration > 0.0 {  
            audioPlayer.setVolume(1.0, fadeDuration: fadeDuration)  
        }
    }

    private func stopAlarm(id: Int, result: FlutterResult) {
        self.cancelNotification(id: String(id))

        self.mixOtherAudios()

        self.vibrate = false
        if self.previousVolume != nil {
            self.setVolume(volume: self.previousVolume!, enable: false)
        }

        if let timer = timers[id] {
            timer.invalidate()
            timers.removeValue(forKey: id)
        }

        if let audioPlayer = self.audioPlayers[id] {
            audioPlayer.stop()
            self.audioPlayers.removeValue(forKey: id)
            self.triggerTimes.removeValue(forKey: id)
            self.tasksQueue[id]?.cancel()
            self.tasksQueue.removeValue(forKey: id)
            self.stopSilentSound()
            self.stopNotificationOnKillService()
            result(true)
        } else {
            result(false)
        }
    }	

    private func stopSilentSound() {
        self.mixOtherAudios()

        if self.audioPlayers.isEmpty {
            self.playSilent = false
            self.silentAudioPlayer?.stop()
            NotificationCenter.default.removeObserver(self)
            SwiftAlarmPlugin.cancelBackgroundTasks()
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

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                    self.previousVolume = enable ? slider.value : nil
                    slider.value = volume
                }
                volumeView.removeFromSuperview()
            }
        }
    }

    private func audioCurrentTime(id: Int, result: FlutterResult) {
        if let audioPlayer = self.audioPlayers[id] {
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

        let ids = Array(self.audioPlayers.keys)

        for id in ids {
            NSLog("SwiftAlarmPlugin: Background check alarm with id \(id)")
            if let audioPlayer = self.audioPlayers[id] {
                let dateTime = self.triggerTimes[id]!
                let currentTime = audioPlayer.deviceCurrentTime
                let time = currentTime + dateTime.timeIntervalSinceNow
                self.audioPlayers[id]!.play(atTime: time)
            }

            let delayInSeconds = self.triggerTimes[id]!.timeIntervalSinceNow
            DispatchQueue.main.async {
                self.timers[id] = Timer.scheduledTimer(timeInterval: delayInSeconds, target: self, selector: #selector(self.executeTask(_:)), userInfo: id, repeats: false)
            }
        }
    }

    private func stopNotificationOnKillService() {
        if audioPlayers.isEmpty && observerAdded {
            NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
            observerAdded = false
        }
    }

    @objc func applicationWillTerminate(_ notification: Notification) {
        let content = UNMutableNotificationContent()
        content.title = notificationTitleOnKill
        content.body = notificationBodyOnKill
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "notification on app kill", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                NSLog("SwiftAlarmPlugin: Failed to show notification on kill service => error: \(error.localizedDescription)")
            } else {
                NSLog("SwiftAlarmPlugin: Trigger notification on app kill")
            }
        }
    }

    private func mixOtherAudios() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("SwiftAlarmPlugin: Error setting up audio session with option mixWithOthers: \(error.localizedDescription)")
        }
    }

    private func duckOtherAudios() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("SwiftAlarmPlugin: Error setting up audio session with option duckOthers: \(error.localizedDescription)")
        }
    }

    /// Runs from AppDelegate when the app is launched
    static public func registerBackgroundTasks() {
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
                self.scheduleAppRefresh()
                sharedInstance.backgroundFetch()
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

    func scheduleNotification(id: String, delayInSeconds: Int, title: String, body: String) {
        // Request permission
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                // Schedule the notification
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = nil

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSeconds), repeats: false)
                let request = UNNotificationRequest(identifier: "alarm-\(id)", content: content, trigger: trigger)

                center.add(request) { error in
                    if let error = error {
                        NSLog("SwiftAlarmPlugin: Error scheduling notification: \(error.localizedDescription)")
                    }
                }
            } else {
                NSLog("SwiftAlarmPlugin: Notification permission denied")
            }
        }
    }

    func cancelNotification(id: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["alarm-\(id)"])
    }
}