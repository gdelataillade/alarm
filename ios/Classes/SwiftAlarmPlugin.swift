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
        self.setUpAudio()

        let args = call.arguments as! NSDictionary
        let assetAudio = args["assetAudio"] as! String
        let delayInSeconds = args["delayInSeconds"] as! Double
        let loopAudio = args["loopAudio"] as! Bool

        let bundle = Bundle.main
        guard let path = bundle.path(
          forResource: assetAudio,
          ofType: nil
        ) else {
          fatalError()
        }

        let url = URL(fileURLWithPath: path)
        do {
          self.audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
          result(false)
        }

        let currentTime = self.audioPlayer.deviceCurrentTime
        let time = currentTime + delayInSeconds

        if loopAudio {
          self.audioPlayer.numberOfLoops = -1
        }

        self.audioPlayer.prepareToPlay()
        self.audioPlayer.play(atTime: time)

        result(true)
      } else if call.method == "stopAlarm" {
        self.audioPlayer.stop()
        result(true)
      } else if call.method == "audioCurrentTime" {
        result(Double(self.audioPlayer.currentTime))
      } else {
        DispatchQueue.main.sync {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
