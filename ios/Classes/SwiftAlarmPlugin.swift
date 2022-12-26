import Flutter
import UIKit
import AVFoundation

public class SwiftAlarmPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.gdelataillade/alarm", binaryMessenger: registrar.messenger())
    let instance = SwiftAlarmPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public var audioPlayer: AVAudioPlayer?

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .default).async {
      if call.method == "setAlarm" {
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
          result(Bool(false))
        }

        let currentTime = self.audioPlayer!.deviceCurrentTime
        let time = currentTime + delayInSeconds
        let res = self.audioPlayer!.play(atTime: time)

        result(Bool(true))
      } else if call.method == "stopAlarm" {
        if self.audioPlayer != nil {
          self.audioPlayer!.stop()
          result(Bool(true))
        } else {
        result(Bool(false))
      }
      } else if call.method == "getPlatformVersion" {
        result("iOS " + UIDevice.current.systemVersion)
      } else {
        DispatchQueue.main.sync {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
