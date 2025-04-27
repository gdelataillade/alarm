import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';

part 'alarm_settings.g.dart';

/// [AlarmSettings] is a model that contains all the settings to customize
/// and set an alarm.
@JsonSerializable()
class AlarmSettings extends Equatable {
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
    this.androidStopAlarmOnTermination = true,
    this.payload,
  });

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  ///
  /// This factory adds backward compatibility for v4 JSON structures
  /// by detecting the absence of certain fields and adjusting them.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) {
    // Check if 'volumeSettings' key is absent, indicating v4 data
    if (!json.containsKey('volumeSettings')) {
      _log
        ..fine('Detected v4 JSON data, applying backward compatibility.')
        ..fine('Data before adjustment: $json');

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

      // Convert dateTime to string so the default JSON parser can handle it
      final dateTimeValue = json['dateTime'];
      if (dateTimeValue == null) {
        throw ArgumentError('dateTime is missing in the JSON data');
      }
      if (dateTimeValue is int) {
        // Convert the int (milliseconds) into a DateTime and then to ISO string
        final dt = DateTime.fromMillisecondsSinceEpoch(dateTimeValue ~/ 1000);
        json['dateTime'] = dt.toIso8601String();
      } else if (dateTimeValue is String) {
        // Already a string, just ensure it's valid
        // Optionally parse and reassign as an ISO 8601 string again
        final dt = DateTime.parse(dateTimeValue);
        json['dateTime'] = dt.toIso8601String();
      } else {
        throw ArgumentError('Invalid dateTime value: $dateTimeValue');
      }

      _log.fine('Adjusted data: $json');
    }

    return _$AlarmSettingsFromJson(json);
  }

  static final _log = Logger('AlarmSettings');

  /// Unique identifier associated with the alarm. Cannot be 0 or -1.
  final int id;

  /// Date and time when the alarm will be triggered.
  final DateTime dateTime;

  /// Path to audio asset to be used as the alarm ringtone. Accepted formats:
  ///
  /// * **Project asset**:
  ///   Specifies an asset bundled with your Flutter project.
  ///   Use this format for assets that are included in your project's
  ///   `pubspec.yaml` file.
  ///   Example: `assets/audio.mp3`
  ///
  /// * **App Documents directory path**:
  ///   Specifies a path relative to your app's Documents directory.
  ///   This is used for files stored in your app's local storage.
  ///   Always use the relative path from the Documents directory, as the full
  ///   path may change when the app updates.
  ///
  ///   For example, if your file is located at:
  ///   `/var/mobile/Containers/Data/Application/<UUID>/Documents/custom_sounds/audio.mp3`
  ///   You should only specify: `custom_sounds/audio.mp3`
  ///
  ///   This ensures the path remains valid even after app updates, as the UUID
  ///   portion of the path may change.
  ///
  /// Note: For Android, the READ_EXTERNAL_STORAGE permission is required in
  /// your `AndroidManifest.xml` to access files from local storage.
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

  /// Whether to stop the alarm when an Android task is terminated by e.g.
  /// swiping away the app from the recent apps list.
  ///
  /// Defaults to `true`. Has no effect on iOS.
  final bool androidStopAlarmOnTermination;

  /// Optional payload to be sent with the alarm. This can be used to pass
  /// additional data to the alarm handler.
  ///
  /// Caller is responsible for serializing and parsing the payload.
  final String? payload;

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
        androidStopAlarmOnTermination: androidStopAlarmOnTermination,
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
    bool? androidStopAlarmOnTermination,
    String? Function()? payload,
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
      androidStopAlarmOnTermination:
          androidStopAlarmOnTermination ?? this.androidStopAlarmOnTermination,
      payload: payload?.call() ?? this.payload,
    );
  }

  @override
  List<Object?> get props => [
        id,
        dateTime,
        assetAudioPath,
        volumeSettings,
        notificationSettings,
        loopAudio,
        vibrate,
        warningNotificationOnKill,
        androidFullScreenIntent,
        allowAlarmOverlap,
        iOSBackgroundAudio,
        androidStopAlarmOnTermination,
        payload,
      ];
}
