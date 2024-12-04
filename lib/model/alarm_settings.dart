import 'package:alarm/model/notification_settings.dart';
import 'package:alarm/model/volume_settings.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:json_annotation/json_annotation.dart';

part 'alarm_settings.g.dart';

/// [AlarmSettings] is a model that contains all the settings to customize
/// and set an alarm.
@JsonSerializable()
class AlarmSettings {
  /// Constructs an instance of `AlarmSettings`.
  const AlarmSettings({
    required this.id,
    required this.dateTime,
    required this.assetAudioPath,
    required this.volumeSettings,
    required this.notificationSettings,
    this.loopAudio = true,
    this.vibrate = true,
    this.warningNotificationOnKill = true,
    this.androidFullScreenIntent = true,
  });

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) =>
      _$AlarmSettingsFromJson(json);

  /// Converts from wire datatype.
  AlarmSettings.fromWire(AlarmSettingsWire wire)
      : id = wire.id,
        dateTime =
            DateTime.fromMillisecondsSinceEpoch(wire.millisecondsSinceEpoch),
        assetAudioPath = wire.assetAudioPath,
        volumeSettings = VolumeSettings.fromWire(wire.volumeSettings),
        notificationSettings =
            NotificationSettings.fromWire(wire.notificationSettings),
        loopAudio = wire.loopAudio,
        vibrate = wire.vibrate,
        warningNotificationOnKill = wire.warningNotificationOnKill,
        androidFullScreenIntent = wire.androidFullScreenIntent;

  /// Unique identifier assiocated with the alarm. Cannot be 0 or -1;
  final int id;

  /// Date and time when the alarm will be triggered.
  final DateTime dateTime;

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

  /// Settings for the alarm volume.
  final VolumeSettings volumeSettings;

  /// Settings for the notification.
  final NotificationSettings notificationSettings;

  /// If true, [assetAudioPath] will repeat indefinitely until alarm is stopped.
  final bool loopAudio;

  /// If true, device will vibrate for 500ms, pause for 500ms and repeat until
  /// alarm is stopped.
  ///
  /// If [loopAudio] is set to false, vibrations will stop when audio ends.
  final bool vibrate;

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

  /// Converts the `AlarmSettings` instance to a JSON object.
  Map<String, dynamic> toJson() => _$AlarmSettingsToJson(this);

  /// Converts to wire datatype which is used for host platform communication.
  AlarmSettingsWire toWire() => AlarmSettingsWire(
        id: id,
        millisecondsSinceEpoch: dateTime.millisecondsSinceEpoch,
        assetAudioPath: assetAudioPath,
        volumeSettings: volumeSettings.toWire(),
        notificationSettings: notificationSettings.toWire(),
        loopAudio: loopAudio,
        vibrate: vibrate,
        warningNotificationOnKill: warningNotificationOnKill,
        androidFullScreenIntent: androidFullScreenIntent,
      );

  /// Creates a copy of `AlarmSettings` but with the given fields replaced with
  /// the new values.
  AlarmSettings copyWith({
    int? id,
    DateTime? dateTime,
    String? assetAudioPath,
    VolumeSettings? volumeSettings,
    NotificationSettings? notificationSettings,
    bool? loopAudio,
    bool? vibrate,
    double? volume,
    bool? volumeEnforced,
    double? fadeDuration,
    List<double>? fadeStopTimes,
    List<double>? fadeStopVolumes,
    String? notificationTitle,
    String? notificationBody,
    bool? warningNotificationOnKill,
    bool? androidFullScreenIntent,
  }) {
    return AlarmSettings(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      assetAudioPath: assetAudioPath ?? this.assetAudioPath,
      volumeSettings: volumeSettings ?? this.volumeSettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      warningNotificationOnKill:
          warningNotificationOnKill ?? this.warningNotificationOnKill,
      androidFullScreenIntent:
          androidFullScreenIntent ?? this.androidFullScreenIntent,
    );
  }
}
