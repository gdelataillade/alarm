import Flutter
import UIKit
import AVFoundation

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.gdelataillade/alarm", binaryMessenger: registrar.messenger())
    let instance = SwiftAlarmPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public var audioPlayer: AVAudioPlayer!

  private func setUpAudio() {
    try! AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    try! AVAudioSession.sharedInstance().setActive(true)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .default).async {
      if call.method == "setAlarm" {
        self.setAlarm(call: call, result: result)
      } else if call.method == "stopAlarm" {
        if self.audioPlayer != nil {
          self.audioPlayer.stop()
          self.audioPlayer = nil
          result(true)
        }
        result(false)
      } else if call.method == "audioCurrentTime" {
        if self.audioPlayer != nil {
          result(Double(self.audioPlayer.currentTime))
        } else {
          result(0.0)
        }
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
    let assetAudio = args["assetAudio"] as! String
    let delayInSeconds = args["delayInSeconds"] as! Double
    let loopAudio = args["loopAudio"] as! Bool

    if let audioPath = Bundle.main.path(forResource: assetAudio, ofType: nil) {
      let audioUrl = URL(fileURLWithPath: audioPath)
      do {
        self.audioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
      } catch {
        result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error loading AVAudioPlayer with given asset path or url", details: nil))
      }
    } else {
      result(FlutterError.init(code: "NATIVE_ERR", message: "[Alarm] Error with audio file: path is \(assetAudio)", details: nil))
    }

    let currentTime = self.audioPlayer.deviceCurrentTime
    let time = currentTime + delayInSeconds

    if loopAudio {
      self.audioPlayer.numberOfLoops = -1
    }

    self.audioPlayer.prepareToPlay()
    self.audioPlayer.play(atTime: time)

    result(true)
  }
}
