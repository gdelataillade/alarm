// Autogenerated from Pigeon (v22.6.1), do not edit directly.
// See also: https://pub.dev/packages/pigeon

import Foundation

#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#else
  #error("Unsupported platform.")
#endif

/// Error class for passing custom error details to Dart side.
final class PigeonError: Error {
  let code: String
  let message: String?
  let details: Any?

  init(code: String, message: String?, details: Any?) {
    self.code = code
    self.message = message
    self.details = details
  }

  var localizedDescription: String {
    return
      "PigeonError(code: \(code), message: \(message ?? "<nil>"), details: \(details ?? "<nil>")"
      }
}

private func wrapResult(_ result: Any?) -> [Any?] {
  return [result]
}

private func wrapError(_ error: Any) -> [Any?] {
  if let pigeonError = error as? PigeonError {
    return [
      pigeonError.code,
      pigeonError.message,
      pigeonError.details,
    ]
  }
  if let flutterError = error as? FlutterError {
    return [
      flutterError.code,
      flutterError.message,
      flutterError.details,
    ]
  }
  return [
    "\(error)",
    "\(type(of: error))",
    "Stacktrace: \(Thread.callStackSymbols)",
  ]
}

private func createConnectionError(withChannelName channelName: String) -> PigeonError {
  return PigeonError(code: "channel-error", message: "Unable to establish connection on channel: '\(channelName)'.", details: "")
}

private func isNullish(_ value: Any?) -> Bool {
  return value is NSNull || value == nil
}

private func nilOrValue<T>(_ value: Any?) -> T? {
  if value is NSNull { return nil }
  return value as! T?
}

/// Errors that can occur when interacting with the Alarm API.
enum AlarmErrorCode: Int {
  case unknown = 0
  /// A plugin internal error. Please report these as bugs on GitHub.
  case pluginInternal = 1
  /// The arguments passed to the method are invalid.
  case invalidArguments = 2
  /// An error occurred while communicating with the native platform.
  case channelError = 3
  /// The required notification permission was not granted.
  ///
  /// Please use an external permission manager such as "permission_handler" to
  /// request the permission from the user.
  case missingNotificationPermission = 4
}

/// [AlarmSettingsWire] is a model that contains all the settings to customize
/// and set an alarm.
///
/// Generated class from Pigeon that represents data sent in messages.
struct AlarmSettingsWire {
  /// Unique identifier assiocated with the alarm. Cannot be 0 or -1;
  var id: Int64
  /// Instant (independent of timezone) when the alarm will be triggered.
  var millisecondsSinceEpoch: Int64
  /// Path to audio asset to be used as the alarm ringtone. Accepted formats:
  ///
  /// * **Project asset**: Specifies an asset bundled with your Flutter project.
  ///  Use this format for assets that are included in your project's
  /// `pubspec.yaml` file.
  ///  Example: `assets/audio.mp3`.
  /// * **Absolute file path**: Specifies a direct file system path to the
  /// audio file. This format is used for audio files stored outside the
  /// Flutter project, such as files saved in the device's internal
  /// or external storage.
  ///  Example: `/path/to/your/audio.mp3`.
  /// * **Relative file path**: Specifies a file path relative to a predefined
  /// base directory in the app's internal storage. This format is convenient
  /// for referring to files that are stored within a specific directory of
  /// your app's internal storage without needing to specify the full path.
  ///  Example: `Audios/audio.mp3`.
  ///
  /// If you want to use aboslute or relative file path, you must request
  /// android storage permission and add the following permission to your
  /// `AndroidManifest.xml`:
  /// `android.permission.READ_EXTERNAL_STORAGE`
  var assetAudioPath: String
  /// Settings for the notification.
  var notificationSettings: NotificationSettingsWire
  /// If true, [assetAudioPath] will repeat indefinitely until alarm is stopped.
  var loopAudio: Bool
  /// If true, device will vibrate for 500ms, pause for 500ms and repeat until
  /// alarm is stopped.
  ///
  /// If [loopAudio] is set to false, vibrations will stop when audio ends.
  var vibrate: Bool
  /// Specifies the system volume level to be set at the designated instant.
  ///
  /// Accepts a value between 0 (mute) and 1 (maximum volume).
  /// When the alarm is triggered, the system volume adjusts to his specified
  /// level. Upon stopping the alarm, the system volume reverts to its prior
  /// setting.
  ///
  /// If left unspecified or set to `null`, the current system volume
  /// at the time of the alarm will be used.
  /// Defaults to `null`.
  var volume: Double? = nil
  /// If true, the alarm volume is enforced, automatically resetting to the
  /// original alarm [volume] if the user attempts to adjust it.
  /// This prevents the user from lowering the alarm volume.
  /// Won't work if app is killed.
  ///
  /// Defaults to false.
  var volumeEnforced: Bool
  /// Duration, in seconds, over which to fade the alarm ringtone.
  /// Set to 0.0 by default, which means no fade.
  var fadeDuration: Double
  /// Whether to show a warning notification when application is killed by user.
  ///
  /// - **Android**: the alarm should still trigger even if the app is killed,
  /// if configured correctly and with the right permissions.
  /// - **iOS**: the alarm will not trigger if the app is killed.
  ///
  /// Recommended: set to `Platform.isIOS` to enable it only
  /// on iOS. Defaults to `true`.
  var warningNotificationOnKill: Bool
  /// Whether to turn screen on and display full screen notification
  /// when android alarm notification is triggered. Enabled by default.
  ///
  /// Some devices will need the Autostart permission to show the full screen
  /// notification. You can check if the permission is granted and request it
  /// with the [auto_start_flutter](https://pub.dev/packages/auto_start_flutter)
  /// package.
  var androidFullScreenIntent: Bool



  // swift-format-ignore: AlwaysUseLowerCamelCase
  static func fromList(_ pigeonVar_list: [Any?]) -> AlarmSettingsWire? {
    let id = pigeonVar_list[0] as! Int64
    let millisecondsSinceEpoch = pigeonVar_list[1] as! Int64
    let assetAudioPath = pigeonVar_list[2] as! String
    let notificationSettings = pigeonVar_list[3] as! NotificationSettingsWire
    let loopAudio = pigeonVar_list[4] as! Bool
    let vibrate = pigeonVar_list[5] as! Bool
    let volume: Double? = nilOrValue(pigeonVar_list[6])
    let volumeEnforced = pigeonVar_list[7] as! Bool
    let fadeDuration = pigeonVar_list[8] as! Double
    let warningNotificationOnKill = pigeonVar_list[9] as! Bool
    let androidFullScreenIntent = pigeonVar_list[10] as! Bool

    return AlarmSettingsWire(
      id: id,
      millisecondsSinceEpoch: millisecondsSinceEpoch,
      assetAudioPath: assetAudioPath,
      notificationSettings: notificationSettings,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volume: volume,
      volumeEnforced: volumeEnforced,
      fadeDuration: fadeDuration,
      warningNotificationOnKill: warningNotificationOnKill,
      androidFullScreenIntent: androidFullScreenIntent
    )
  }
  func toList() -> [Any?] {
    return [
      id,
      millisecondsSinceEpoch,
      assetAudioPath,
      notificationSettings,
      loopAudio,
      vibrate,
      volume,
      volumeEnforced,
      fadeDuration,
      warningNotificationOnKill,
      androidFullScreenIntent,
    ]
  }
}

/// Model for notification settings.
///
/// Generated class from Pigeon that represents data sent in messages.
struct NotificationSettingsWire {
  /// Title of the notification to be shown when alarm is triggered.
  var title: String
  /// Body of the notification to be shown when alarm is triggered.
  var body: String
  /// The text to display on the stop button of the notification.
  ///
  /// Won't work on iOS if app was killed.
  /// If null, button will not be shown. Null by default.
  var stopButton: String? = nil
  /// The icon to display on the notification.
  ///
  /// **Only customizable for Android. On iOS, it will use app default icon.**
  ///
  /// This refers to the small icon that is displayed in the
  /// status bar and next to the notification content in both collapsed
  /// and expanded views.
  ///
  /// Note that the icon must be monochrome and on a transparent background and
  /// preferably 24x24 dp in size.
  ///
  /// **Only PNG and XML formats are supported at the moment.
  /// Please open an issue to request support for more formats.**
  ///
  /// You must add your icon to your Android project's `res/drawable` directory.
  /// Example: `android/app/src/main/res/drawable/notification_icon.png`
  ///
  /// And pass: `icon: notification_icon` without the file extension.
  ///
  /// If `null`, the default app icon will be used.
  /// Defaults to `null`.
  var icon: String? = nil



  // swift-format-ignore: AlwaysUseLowerCamelCase
  static func fromList(_ pigeonVar_list: [Any?]) -> NotificationSettingsWire? {
    let title = pigeonVar_list[0] as! String
    let body = pigeonVar_list[1] as! String
    let stopButton: String? = nilOrValue(pigeonVar_list[2])
    let icon: String? = nilOrValue(pigeonVar_list[3])

    return NotificationSettingsWire(
      title: title,
      body: body,
      stopButton: stopButton,
      icon: icon
    )
  }
  func toList() -> [Any?] {
    return [
      title,
      body,
      stopButton,
      icon,
    ]
  }
}

private class FlutterBindingsPigeonCodecReader: FlutterStandardReader {
  override func readValue(ofType type: UInt8) -> Any? {
    switch type {
    case 129:
      let enumResultAsInt: Int? = nilOrValue(self.readValue() as! Int?)
      if let enumResultAsInt = enumResultAsInt {
        return AlarmErrorCode(rawValue: enumResultAsInt)
      }
      return nil
    case 130:
      return AlarmSettingsWire.fromList(self.readValue() as! [Any?])
    case 131:
      return NotificationSettingsWire.fromList(self.readValue() as! [Any?])
    default:
      return super.readValue(ofType: type)
    }
  }
}

private class FlutterBindingsPigeonCodecWriter: FlutterStandardWriter {
  override func writeValue(_ value: Any) {
    if let value = value as? AlarmErrorCode {
      super.writeByte(129)
      super.writeValue(value.rawValue)
    } else if let value = value as? AlarmSettingsWire {
      super.writeByte(130)
      super.writeValue(value.toList())
    } else if let value = value as? NotificationSettingsWire {
      super.writeByte(131)
      super.writeValue(value.toList())
    } else {
      super.writeValue(value)
    }
  }
}

private class FlutterBindingsPigeonCodecReaderWriter: FlutterStandardReaderWriter {
  override func reader(with data: Data) -> FlutterStandardReader {
    return FlutterBindingsPigeonCodecReader(data: data)
  }

  override func writer(with data: NSMutableData) -> FlutterStandardWriter {
    return FlutterBindingsPigeonCodecWriter(data: data)
  }
}

class FlutterBindingsPigeonCodec: FlutterStandardMessageCodec, @unchecked Sendable {
  static let shared = FlutterBindingsPigeonCodec(readerWriter: FlutterBindingsPigeonCodecReaderWriter())
}

/// Generated protocol from Pigeon that represents a handler of messages from Flutter.
protocol AlarmApi {
  func setAlarm(alarmSettings: AlarmSettingsWire) throws
  func stopAlarm(alarmId: Int64) throws
  func isRinging(alarmId: Int64?) throws -> Bool
  func setWarningNotificationOnKill(title: String, body: String) throws
  func disableWarningNotificationOnKill() throws
}

/// Generated setup class from Pigeon to handle messages through the `binaryMessenger`.
class AlarmApiSetup {
  static var codec: FlutterStandardMessageCodec { FlutterBindingsPigeonCodec.shared }
  /// Sets up an instance of `AlarmApi` to handle messages through the `binaryMessenger`.
  static func setUp(binaryMessenger: FlutterBinaryMessenger, api: AlarmApi?, messageChannelSuffix: String = "") {
    let channelSuffix = messageChannelSuffix.count > 0 ? ".\(messageChannelSuffix)" : ""
    let setAlarmChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.alarm.AlarmApi.setAlarm\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      setAlarmChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let alarmSettingsArg = args[0] as! AlarmSettingsWire
        do {
          try api.setAlarm(alarmSettings: alarmSettingsArg)
          reply(wrapResult(nil))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      setAlarmChannel.setMessageHandler(nil)
    }
    let stopAlarmChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.alarm.AlarmApi.stopAlarm\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      stopAlarmChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let alarmIdArg = args[0] as! Int64
        do {
          try api.stopAlarm(alarmId: alarmIdArg)
          reply(wrapResult(nil))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      stopAlarmChannel.setMessageHandler(nil)
    }
    let isRingingChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.alarm.AlarmApi.isRinging\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      isRingingChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let alarmIdArg: Int64? = nilOrValue(args[0])
        do {
          let result = try api.isRinging(alarmId: alarmIdArg)
          reply(wrapResult(result))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      isRingingChannel.setMessageHandler(nil)
    }
    let setWarningNotificationOnKillChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.alarm.AlarmApi.setWarningNotificationOnKill\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      setWarningNotificationOnKillChannel.setMessageHandler { message, reply in
        let args = message as! [Any?]
        let titleArg = args[0] as! String
        let bodyArg = args[1] as! String
        do {
          try api.setWarningNotificationOnKill(title: titleArg, body: bodyArg)
          reply(wrapResult(nil))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      setWarningNotificationOnKillChannel.setMessageHandler(nil)
    }
    let disableWarningNotificationOnKillChannel = FlutterBasicMessageChannel(name: "dev.flutter.pigeon.alarm.AlarmApi.disableWarningNotificationOnKill\(channelSuffix)", binaryMessenger: binaryMessenger, codec: codec)
    if let api = api {
      disableWarningNotificationOnKillChannel.setMessageHandler { _, reply in
        do {
          try api.disableWarningNotificationOnKill()
          reply(wrapResult(nil))
        } catch {
          reply(wrapError(error))
        }
      }
    } else {
      disableWarningNotificationOnKillChannel.setMessageHandler(nil)
    }
  }
}
/// Generated protocol from Pigeon that represents Flutter messages that can be called from Swift.
protocol AlarmTriggerApiProtocol {
  func alarmRang(alarmId alarmIdArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void)
  func alarmStopped(alarmId alarmIdArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void)
}
class AlarmTriggerApi: AlarmTriggerApiProtocol {
  private let binaryMessenger: FlutterBinaryMessenger
  private let messageChannelSuffix: String
  init(binaryMessenger: FlutterBinaryMessenger, messageChannelSuffix: String = "") {
    self.binaryMessenger = binaryMessenger
    self.messageChannelSuffix = messageChannelSuffix.count > 0 ? ".\(messageChannelSuffix)" : ""
  }
  var codec: FlutterBindingsPigeonCodec {
    return FlutterBindingsPigeonCodec.shared
  }
  func alarmRang(alarmId alarmIdArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void) {
    let channelName: String = "dev.flutter.pigeon.alarm.AlarmTriggerApi.alarmRang\(messageChannelSuffix)"
    let channel = FlutterBasicMessageChannel(name: channelName, binaryMessenger: binaryMessenger, codec: codec)
    channel.sendMessage([alarmIdArg] as [Any?]) { response in
      guard let listResponse = response as? [Any?] else {
        completion(.failure(createConnectionError(withChannelName: channelName)))
        return
      }
      if listResponse.count > 1 {
        let code: String = listResponse[0] as! String
        let message: String? = nilOrValue(listResponse[1])
        let details: String? = nilOrValue(listResponse[2])
        completion(.failure(PigeonError(code: code, message: message, details: details)))
      } else {
        completion(.success(Void()))
      }
    }
  }
  func alarmStopped(alarmId alarmIdArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void) {
    let channelName: String = "dev.flutter.pigeon.alarm.AlarmTriggerApi.alarmStopped\(messageChannelSuffix)"
    let channel = FlutterBasicMessageChannel(name: channelName, binaryMessenger: binaryMessenger, codec: codec)
    channel.sendMessage([alarmIdArg] as [Any?]) { response in
      guard let listResponse = response as? [Any?] else {
        completion(.failure(createConnectionError(withChannelName: channelName)))
        return
      }
      if listResponse.count > 1 {
        let code: String = listResponse[0] as! String
        let message: String? = nilOrValue(listResponse[1])
        let details: String? = nilOrValue(listResponse[2])
        completion(.failure(PigeonError(code: code, message: message, details: details)))
      } else {
        completion(.success(Void()))
      }
    }
  }
}