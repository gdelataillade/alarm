import Flutter
import UIKit
import AVFoundation

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.gdelataillade/alarm", binaryMessenger: registrar.messenger())
    let instance = SwiftAlarmPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var audioPlayers: [Int: AVAudioPlayer] = [:]

  private var notifOnKillEnabled: Bool!
  private var notificationTitleOnKill: String!
  private var notificationBodyOnKill: String!

  private var observerAdded = false;

  private func setUpAudio() {
    try! AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    try! AVAudioSession.sharedInstance().setActive(true)
  }

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
    self.setUpAudio()

    let args = call.arguments as! Dictionary<String, Any>

    notifOnKillEnabled = args["notifOnKillEnabled"] as! Bool
    notificationTitleOnKill = args["notifTitleOnAppKill"] as! String
    notificationBodyOnKill = args["notifDescriptionOnAppKill"] as! String

    NSLog("[DEV] ===> stop notif on kill service, observerAdded: \(observerAdded)");
    if notifOnKillEnabled && !observerAdded {
      observerAdded = true
      NotificationCenter.default.addObserver(self, selector: #selector(applicationWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
    }

    let id = args["id"] as! Int
    let assetAudio = args["assetAudio"] as! String
    let delayInSeconds = args["delayInSeconds"] as! Double
    let loopAudio = args["loopAudio"] as! Bool
    let fadeDuration = args["fadeDuration"] as! Double

    if let audioPath = Bundle.main.path(forResource: assetAudio, ofType: nil) {
      let audioUrl = URL(fileURLWithPath: audioPath)
      do {
        let audioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
        self.audioPlayers[id] = audioPlayer
      } catch {
        result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error loading AVAudioPlayer with given asset path or url", details: nil))
      }
    } else {
      result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error with audio file: path is \(assetAudio)", details: nil))
    }

    let currentTime = self.audioPlayers[id]!.deviceCurrentTime
    let time = currentTime + delayInSeconds

    if loopAudio {
      self.audioPlayers[id]!.numberOfLoops = -1
    }

    self.audioPlayers[id]!.prepareToPlay()

    if fadeDuration > 0.0 {
      self.audioPlayers[id]!.volume = 0.1
      self.audioPlayers[id]!.play(atTime: time)
      DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
        self.audioPlayers[id]!.setVolume(1, fadeDuration: fadeDuration)
      }
    } else {
      self.audioPlayers[id]!.play(atTime: time)
    }

    result(true)
  }

  private func stopAlarm(id: Int, result: FlutterResult) {
    if let audioPlayer = self.audioPlayers[id] {
      audioPlayer.stop()
      self.audioPlayers.removeValue(forKey: id)
      self.stopNotificationOnKillService();
      result(true)
    } else {
      result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error: no alarm found with id \(id)", details: nil))
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
        NSLog("[DEV] ===> Failed to add notification on kill service with error: \(error.localizedDescription)")
      } else {
        NSLog("[DEV] ===> Added notification on kill service")
      }
    }
  }
}
