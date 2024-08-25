import 'package:alarm/model/notification_action_settings.dart';
import 'package:flutter/widgets.dart';

@immutable

/// [AlarmSettings] is a model that contains all the settings to customize
/// and set an alarm.
class AlarmSettings {
  /// Constructs an instance of `AlarmSettings`.
  const AlarmSettings({
    required this.id,
    required this.dateTime,
    required this.assetAudioPath,
    required this.notificationTitle,
    required this.notificationBody,
    this.loopAudio = true,
    this.vibrate = true,
    this.volume,
    this.fadeDuration = 0.0,
    this.enableNotificationOnKill = true,
    this.androidFullScreenIntent = true,
    this.notificationActionSettings = const NotificationActionSettings(),
  });

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        id: json['id'] as int,
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        loopAudio: json['loopAudio'] as bool,
        vibrate: json['vibrate'] as bool? ?? true,
        volume: json['volume'] as double?,
        fadeDuration: json['fadeDuration'] as double,
        notificationTitle: json['notificationTitle'] as String? ?? '',
        notificationBody: json['notificationBody'] as String? ?? '',
        enableNotificationOnKill:
            json['enableNotificationOnKill'] as bool? ?? true,
        androidFullScreenIntent:
            json['androidFullScreenIntent'] as bool? ?? true,
        notificationActionSettings: NotificationActionSettings.fromJson(
          json['notificationActionSettings'] as Map<String, dynamic>? ??
              const {},
        ),
      );

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

  /// If true, [assetAudioPath] will repeat indefinitely until alarm is stopped.
  final bool loopAudio;

  /// If true, device will vibrate for 500ms, pause for 500ms and repeat until
  /// alarm is stopped.
  ///
  /// If [loopAudio] is set to false, vibrations will stop when audio ends.
  final bool vibrate;

  /// Specifies the system volume level to be set at the designated [dateTime].
  ///
  /// Accepts a value between 0 (mute) and 1 (maximum volume).
  /// When the alarm is triggered at [dateTime], the system volume adjusts to
  /// this specified level. Upon stopping the alarm, the system volume reverts
  /// to its prior setting.
  ///
  /// If left unspecified or set to `null`, the current system volume
  /// at the time of the alarm will be used.
  /// Defaults to `null`.
  final double? volume;

  /// Duration, in seconds, over which to fade the alarm ringtone.
  /// Set to 0.0 by default, which means no fade.
  final double fadeDuration;

  /// Title of the notification to be shown when alarm is triggered.
  final String notificationTitle;

  /// Body of the notification to be shown when alarm is triggered.
  final String notificationBody;

  /// Whether to show a notification when application is killed by user.
  ///
  /// - Android: the alarm should still trigger even if the app is killed,
  /// if configured correctly and with the right permissions.
  /// - iOS: the alarm will not trigger if the app is killed.
  ///
  /// Recommended: set to `Platform.isIOS` to enable it only
  /// on iOS. Defaults to `true`.
  final bool enableNotificationOnKill;

  /// Whether to turn screen on and display full screen notification
  /// when android alarm notification is triggered. Enabled by default.
  ///
  /// Some devices will need the Autostart permission to show the full screen
  /// notification. You can check if the permission is granted and request it
  /// with the [auto_start_flutter](https://pub.dev/packages/auto_start_flutter)
  /// package.
  final bool androidFullScreenIntent;

  /// Settings for the notification actions.
  ///
  /// Won't work on iOS if app was killed. Disabled by default.
  final NotificationActionSettings notificationActionSettings;

  /// Returns a hash code for this `AlarmSettings` instance using
  /// Jenkins hash function.
  @override
  int get hashCode {
    var hash = 0;

    hash = hash ^ id.hashCode;
    hash = hash ^ dateTime.hashCode;
    hash = hash ^ assetAudioPath.hashCode;
    hash = hash ^ loopAudio.hashCode;
    hash = hash ^ vibrate.hashCode;
    hash = hash ^ volume.hashCode;
    hash = hash ^ fadeDuration.hashCode;
    hash = hash ^ (notificationTitle.hashCode);
    hash = hash ^ (notificationBody.hashCode);
    hash = hash ^ enableNotificationOnKill.hashCode;
    hash = hash ^ androidFullScreenIntent.hashCode;
    hash = hash ^ notificationActionSettings.hashCode;
    hash = hash & 0x3fffffff;

    return hash;
  }

  /// Creates a copy of `AlarmSettings` but with the given fields replaced with
  /// the new values.
  AlarmSettings copyWith({
    int? id,
    DateTime? dateTime,
    String? assetAudioPath,
    bool? loopAudio,
    bool? vibrate,
    double? volume,
    double? fadeDuration,
    String? notificationTitle,
    String? notificationBody,
    bool? enableNotificationOnKill,
    bool? androidFullScreenIntent,
    NotificationActionSettings? notificationActionSettings,
  }) {
    return AlarmSettings(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      assetAudioPath: assetAudioPath ?? this.assetAudioPath,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      volume: volume ?? this.volume,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      enableNotificationOnKill:
          enableNotificationOnKill ?? this.enableNotificationOnKill,
      androidFullScreenIntent:
          androidFullScreenIntent ?? this.androidFullScreenIntent,
      notificationActionSettings:
          notificationActionSettings ?? this.notificationActionSettings,
    );
  }

  /// Converts this `AlarmSettings` instance to JSON data.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'volume': volume,
        'fadeDuration': fadeDuration,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
        'enableNotificationOnKill': enableNotificationOnKill,
        'androidFullScreenIntent': androidFullScreenIntent,
        'notificationActionSettings': notificationActionSettings.toJson(),
      };

  /// Returns all the properties of `AlarmSettings` for debug purposes.
  @override
  String toString() {
    final json = toJson();
    json['dateTime'] =
        DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int);

    return 'AlarmSettings: $json';
  }

  /// Compares two AlarmSettings.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSettings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          dateTime == other.dateTime &&
          assetAudioPath == other.assetAudioPath &&
          loopAudio == other.loopAudio &&
          vibrate == other.vibrate &&
          volume == other.volume &&
          fadeDuration == other.fadeDuration &&
          notificationTitle == other.notificationTitle &&
          notificationBody == other.notificationBody &&
          enableNotificationOnKill == other.enableNotificationOnKill &&
          androidFullScreenIntent == other.androidFullScreenIntent &&
          notificationActionSettings == other.notificationActionSettings;
}
