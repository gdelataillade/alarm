import 'package:pigeon/pigeon.dart';

// After modifying this file run:
// dart run pigeon --input pigeons/alarm_api.dart && dart format .

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/platform_bindings.g.dart',
    dartPackageName: 'alarm',
    swiftOut: 'ios/Classes/generated/FlutterBindings.g.swift',
    kotlinOut:
        'android/src/main/kotlin/com/gdelataillade/alarm/generated/FlutterBindings.g.kt',
  ),
)

/// [AlarmSettingsWire] is a model that contains all the settings to customize
/// and set an alarm.
class AlarmSettingsWire {
  /// Constructs an instance of [AlarmSettingsWire].
  const AlarmSettingsWire({
    required this.id,
    required this.millisecondsSinceEpoch,
    required this.assetAudioPath,
    required this.notificationSettings,
    this.loopAudio = true,
    this.vibrate = true,
    this.volume,
    this.volumeEnforced = false,
    this.fadeDuration = 0.0,
    this.warningNotificationOnKill = true,
    this.androidFullScreenIntent = true,
  });

  /// Unique identifier assiocated with the alarm. Cannot be 0 or -1;
  final int id;

  /// Instant (independent of timezone) when the alarm will be triggered.
  final int millisecondsSinceEpoch;

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
  final String assetAudioPath;

  /// Settings for the notification.
  final NotificationSettingsWire notificationSettings;

  /// If true, [assetAudioPath] will repeat indefinitely until alarm is stopped.
  final bool loopAudio;

  /// If true, device will vibrate for 500ms, pause for 500ms and repeat until
  /// alarm is stopped.
  ///
  /// If [loopAudio] is set to false, vibrations will stop when audio ends.
  final bool vibrate;

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
  final double? volume;

  /// If true, the alarm volume is enforced, automatically resetting to the
  /// original alarm [volume] if the user attempts to adjust it.
  /// This prevents the user from lowering the alarm volume.
  /// Won't work if app is killed.
  ///
  /// Defaults to false.
  final bool volumeEnforced;

  /// Duration, in seconds, over which to fade the alarm ringtone.
  /// Set to 0.0 by default, which means no fade.
  final double fadeDuration;

  /// Whether to show a warning notification when application is killed by user.
  ///
  /// - **Android**: the alarm should still trigger even if the app is killed,
  /// if configured correctly and with the right permissions.
  /// - **iOS**: the alarm will not trigger if the app is killed.
  ///
  /// Recommended: set to `Platform.isIOS` to enable it only
  /// on iOS. Defaults to `true`.
  final bool warningNotificationOnKill;

  /// Whether to turn screen on and display full screen notification
  /// when android alarm notification is triggered. Enabled by default.
  ///
  /// Some devices will need the Autostart permission to show the full screen
  /// notification. You can check if the permission is granted and request it
  /// with the [auto_start_flutter](https://pub.dev/packages/auto_start_flutter)
  /// package.
  final bool androidFullScreenIntent;
}

/// Model for notification settings.
class NotificationSettingsWire {
  /// Constructs an instance of [NotificationSettingsWire].
  ///
  /// Open PR if you want more features.
  const NotificationSettingsWire({
    required this.title,
    required this.body,
    this.stopButton,
    this.icon,
  });

  /// Title of the notification to be shown when alarm is triggered.
  final String title;

  /// Body of the notification to be shown when alarm is triggered.
  final String body;

  /// The text to display on the stop button of the notification.
  ///
  /// Won't work on iOS if app was killed.
  /// If null, button will not be shown. Null by default.
  final String? stopButton;

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
  final String? icon;
}

/// Errors that can occur when interacting with the Alarm API.
enum AlarmErrorCode {
  unknown,

  /// A plugin internal error. Please report these as bugs on GitHub.
  pluginInternal,

  /// The arguments passed to the method are invalid.
  invalidArguments,

  /// An error occurred while communicating with the native platform.
  channelError,

  /// The required notification permission was not granted.
  ///
  /// Please use an external permission manager such as "permission_handler" to
  /// request the permission from the user.
  missingNotificationPermission,
}

@HostApi()
abstract class AlarmApi {
  void setAlarm({required AlarmSettingsWire alarmSettings});

  void stopAlarm({required int alarmId});

  bool isRinging({required int? alarmId});

  void setWarningNotificationOnKill({
    required String title,
    required String body,
  });

  void disableWarningNotificationOnKill();
}

@FlutterApi()
abstract class AlarmTriggerApi {
  @async
  void alarmRang(int alarmId);

  @async
  void alarmStopped(int alarmId);
}
