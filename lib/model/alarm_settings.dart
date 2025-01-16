import 'package:alarm/alarm.dart';
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
    this.allowAlarmOverlap = false,
    this.iOSBackgroundAudio = true,
  });

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  ///
  /// This factory adds backward compatibility for v4 JSON structures
  /// by detecting the absence of certain fields and adjusting them.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) {
    // Check if 'volumeSettings' key is absent, indicating v4 data
    if (!json.containsKey('volumeSettings')) {
      alarmPrint('Detected v4 JSON data, adjusting fields...');
      alarmPrint('Data to adjust: $json');
      // Process volume settings for v4
      final volume = (json['volume'] as num?)?.toDouble();
      final fadeDurationSeconds = (json['fadeDuration'] as num?)?.toDouble();
      final fadeDurationMillis =
          (fadeDurationSeconds != null && fadeDurationSeconds > 0)
              ? (fadeDurationSeconds * 1000).toInt()
              : null;
      final volumeEnforced = json['volumeEnforced'] as bool? ?? false;

      json['volumeSettings'] = {
        'volume': volume,
        'fadeDuration': fadeDurationMillis,
        'fadeSteps': <Map<String, dynamic>>[],
        'volumeEnforced': volumeEnforced,
      };

      // Default `allowAlarmOverlap` to false for v4
      json['allowAlarmOverlap'] = json['allowAlarmOverlap'] ?? false;

      // Default `iOSBackgroundAudio` to true for v4
      json['iOSBackgroundAudio'] = json['iOSBackgroundAudio'] ?? true;

      alarmPrint(
        'dateTime: ${json['dateTime']} of type ${json['dateTime'].runtimeType}',
      );

      // Adjust `dateTime` field for v4
      if (json['dateTime'] != null) {
        if (json['dateTime'] is int) {
          final dateTimeValue = json['dateTime'] as int;
          // In v4, dateTime was stored in microseconds, convert to milliseconds
          json['dateTime'] = dateTimeValue ~/ 1000;
        } else if (json['dateTime'] is String) {
          // Parse ISO 8601 date string
          json['dateTime'] =
              DateTime.parse(json['dateTime'] as String).millisecondsSinceEpoch;
        } else {
          throw ArgumentError('Invalid dateTime value: ${json['dateTime']}');
        }
      } else {
        throw ArgumentError('dateTime is missing in the JSON data');
      }
      alarmPrint('Adjusted data: $json');
    } else {
      alarmPrint('Detected v5 JSON data, no adjustments needed.');
    }
    alarmPrint('Running fromJson with data: $json');
    // Parse using the default parser (v5)
    return _$AlarmSettingsFromJson(json);
  }

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
        androidFullScreenIntent = wire.androidFullScreenIntent,
        allowAlarmOverlap = wire.allowAlarmOverlap,
        iOSBackgroundAudio = wire.iOSBackgroundAudio;

  /// Unique identifier associated with the alarm. Cannot be 0 or -1.
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

  /// Whether the alarm should ring if another alarm is already ringing.
  ///
  /// Defaults to `false`.
  final bool allowAlarmOverlap;

  /// iOS apps are killed if they remain inactive in the background. Android
  /// does not have this limitation due to native AlarmManager support.
  ///
  /// This flag controls whether a silent audio player should start playing when
  /// there is an active alarm. Apps that already have background activity can
  /// set this to `false` to conserve battery.
  ///
  /// DO NOT set this to `false` unless you are certain. Otherwise your alarms
  /// may not ring!
  ///
  /// Defaults to `true`. Has no effect on Android.
  final bool iOSBackgroundAudio;

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
        allowAlarmOverlap: allowAlarmOverlap,
        iOSBackgroundAudio: iOSBackgroundAudio,
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
    bool? allowAlarmOverlap,
    bool? iOSBackgroundAudio,
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
      allowAlarmOverlap: allowAlarmOverlap ?? this.allowAlarmOverlap,
      iOSBackgroundAudio: iOSBackgroundAudio ?? this.iOSBackgroundAudio,
    );
  }
}
