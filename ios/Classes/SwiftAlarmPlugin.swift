import Flutter
import UIKit
import AVFoundation
import AudioToolbox
import MediaPlayer

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
  #if targetEnvironment(simulator)
    private let isDevice = false
  #else
    private let isDevice = true
  #endif

  private var registrar: FlutterPluginRegistrar!

  // MARK: - FlutterPlugin Methods
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.gdelataillade/alarm", binaryMessenger: registrar.messenger())
    let instance = SwiftAlarmPlugin()

    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var audioPlayers: [Int: AVAudioPlayer] = [:]
  private var silentAudioPlayer: AVAudioPlayer?
  private var silentAudioTimer: Timer?
  private var tasksQueue: [Int: DispatchWorkItem] = [:]
  private var triggerTimes: [Int: Date] = [:]

  private var notifOnKillEnabled: Bool!
  private var notificationTitleOnKill: String!
  private var notificationBodyOnKill: String!

  private var observerAdded = false
  private var vibrate = false
  private var playSilent = false
  private var previousVolume: Float? = nil


  // MARK: - setUpAudioSession
  private func setUpAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("SwiftAlarmPlugin: Error setting up audio session: \(error.localizedDescription)")
    }
  }

  // MARK: - handle
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

  // MARK: - setAlarm
  private func setAlarm(call: FlutterMethodCall, result: FlutterResult) {
    self.setUpAudioSession()

    let args = call.arguments as! Dictionary<String, Any>

    notifOnKillEnabled = args["notifOnKillEnabled"] as! Bool
    notificationTitleOnKill = args["notifTitleOnAppKill"] as! String
    notificationBodyOnKill = args["notifDescriptionOnAppKill"] as! String

    if notifOnKillEnabled && !observerAdded {
      observerAdded = true
      NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
    }

    let id = args["id"] as! Int
    let delayInSeconds = args["delayInSeconds"] as! Double
    let loopAudio = args["loopAudio"] as! Bool
    let fadeDuration = args["fadeDuration"] as! Double
    let vibrationsEnabled = args["vibrate"] as! Bool
    let volumeMax = args["volumeMax"] as! Bool

    var assetAudio = args["assetAudio"] as! String

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
      self.stopSilentSound()
      self.handleAlarmAfterDelay(
        id: id,
        triggerTime: dateTime,
        fadeDuration: fadeDuration,
        vibrationsEnabled: vibrationsEnabled,
        audioLoop: loopAudio,
        volumeMax: volumeMax
       )
    })

    DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds, execute: self.tasksQueue[id]!)

    result(true)
  }

  // MARK: - startSilentSound
  private func startSilentSound() {
      let filename = registrar.lookupKey(forAsset: "assets/blank.mp3", fromPackage: "alarm")
      if let audioPath = Bundle.main.path(forResource: filename, ofType: nil) {
        let audioUrl = URL(fileURLWithPath: audioPath)
        do {
          self.silentAudioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
          self.silentAudioPlayer?.numberOfLoops = -1
          self.silentAudioPlayer?.prepareToPlay()
          self.playSilent = true
          self.loopSilentSound()
        } catch {
          NSLog("SwiftAlarmPlugin: Error: Could not create audio player: \(error)")
        }
      } else {
        NSLog("SwiftAlarmPlugin: Error: Could not find audio file")
      }
  }

  // MARK: - loopSilentSound
  private func loopSilentSound() {
    silentAudioPlayer?.play()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if self.playSilent {
        self.silentAudioPlayer?.pause()
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
        if self.playSilent {
          self.loopSilentSound()
        }
      }
    }
  }

  // MARK: - handleAlarmAfterDelay
  private func handleAlarmAfterDelay(id: Int, triggerTime: Date, fadeDuration: Double, vibrationsEnabled: Bool, audioLoop: Bool, volumeMax: Bool) {
    guard let audioPlayer = self.audioPlayers[id], let storedTriggerTime = triggerTimes[id], triggerTime == storedTriggerTime else {
      return
    }

    if fadeDuration > 0.0 {
      if (volumeMax) {
        self.setVolume(volume: 0.15, showSystemUI: true)
      } else {
        audioPlayer.setVolume(1, fadeDuration: fadeDuration)
      }
    } else {
      if (volumeMax) {
        self.setVolume(volume: 0.15, showSystemUI: true)
      }
    }

    self.vibrate = vibrationsEnabled
    self.triggerVibrations()

    if !audioLoop {
      let audioDuration = audioPlayer.duration
      DispatchQueue.main.asyncAfter(deadline: .now() + audioDuration) {
        self.vibrate = false
      }
    }
  }

  // MARK: - stopAlarm
  private func stopAlarm(id: Int, result: FlutterResult) {
    self.vibrate = false
    if (self.previousVolume != nil) {
      setVolume(volume: self.previousVolume!, showSystemUI: true)
      self.previousVolume = nil
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
    if self.audioPlayers.isEmpty {
      NSLog("SwiftAlarmPlugin: stop playing silent because audioPlayers is empty")
      self.playSilent = false
      self.silentAudioPlayer?.stop()
    } else {
      NSLog("SwiftAlarmPlugin: continue playing silent because audioPlayers is not empty: \(self.audioPlayers.count)")
    }
  }

  // MARK: - triggerVibrations
  private func triggerVibrations() {
    if vibrate && isDevice {
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          AudioServicesDisposeSystemSoundID(kSystemSoundID_Vibrate)
          self.triggerVibrations()
        }
    }
  }

  // MARK: - setVolume
  public func setVolume(volume: Float, showSystemUI: Bool) {
    DispatchQueue.main.async {
      let volumeView = MPVolumeView()

      if (!showSystemUI) {
        volumeView.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
        volumeView.showsVolumeSlider = false
        UIApplication.shared.delegate!.window!?.rootViewController!.view.addSubview(volumeView)
      }

      let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
      self.previousVolume = slider?.value

      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) {
        slider?.value = volume
        volumeView.removeFromSuperview()
      }
    }
  }

  // MARK: - audioCurrentTime
  private func audioCurrentTime(id: Int, result: FlutterResult) {
    if let audioPlayer = self.audioPlayers[id] {
      let time = Double(audioPlayer.currentTime)
      result(time)
    } else {
      result(0.0)
    }
  }

  // MARK: - stopNotificationOnKillService
  private func stopNotificationOnKillService() {
    if audioPlayers.isEmpty && observerAdded {
      NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
      observerAdded = false
    }
  }

  // MARK: - applicationWillTerminate
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
        NSLog("SwiftAlarmPlugin: Show notification on kill now")
      }
    }
  }
}
