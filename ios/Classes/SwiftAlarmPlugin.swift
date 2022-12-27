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

        self.audioPlayer.prepareToPlay()

        // Schedule the audio to play after the specified delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
          self.audioPlayer.play()
          result(true)
        }
      } else if call.method == "stopAlarm" {
        if self.audioPlayer != nil {
          self.audioPlayer.stop()
          result(true)
        } else {
          result(false)
        }
      } else {
        DispatchQueue.main.sync {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
