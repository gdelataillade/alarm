import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:logging/logging.dart';

part 'alarm_settings.g.dart';

/// Backs [AlarmSettings.defaultStaleAfter].
///
/// Top level because `json_serializable` copies a constructor default into
/// the generated part verbatim, where a static member of the class is not in
/// scope. [AlarmSettings.defaultStaleAfter] is the name to use.
const _defaultStaleAfter = Duration(minutes: 15);

/// [AlarmSettings] is a model that contains all the settings to customize
/// and set an alarm.
@JsonSerializable()
class AlarmSettings extends Equatable {
  /// Constructs an instance of `AlarmSettings`.
  const AlarmSettings({
    required this.id,
    required this.dateTime,
    required this.volumeSettings,
    required this.notificationSettings,
    this.assetAudioPath,
    this.loopAudio = true,
    this.vibrate = true,
    this.warningNotificationOnKill = true,
    this.androidFullScreenIntent = true,
    this.allowAlarmOverlap = false,
    this.allowSameSecondScheduling = false,
    this.iOSBackgroundAudio = true,
    this.androidStopAlarmOnTermination = true,
    this.preferConnectedAudioDevice = false,
    this.payload,
    this.androidSnoozeDuration,
    this.androidStaleAfter = _defaultStaleAfter,
    this.androidAlarmClock = true,
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
      // The generated VolumeSettings parser reads durations in microseconds.
      final fadeDurationMicros =
          (fadeDurationSeconds != null && fadeDurationSeconds > 0)
              ? (fadeDurationSeconds * Duration.microsecondsPerSecond).toInt()
              : null;
      final volumeEnforced = json['volumeEnforced'] as bool? ?? false;

      json['volumeSettings'] = {
        'volume': volume,
        'fadeDuration': fadeDurationMicros,
        'fadeSteps': <Map<String, dynamic>>[],
        'volumeEnforced': volumeEnforced,
      };

      // Default `allowAlarmOverlap` to false for v4
      json['allowAlarmOverlap'] = json['allowAlarmOverlap'] ?? false;

      // Default `allowSameSecondScheduling` to false for v4
      json['allowSameSecondScheduling'] =
          json['allowSameSecondScheduling'] ?? false;

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

  /// Shortest [androidSnoozeDuration] the platform will honour.
  ///
  /// Below this, Android scheduling stops using `AlarmManager` and falls back
  /// to an in-process timer that survives neither process death nor
  /// cancellation — so a shorter snooze could be neither guaranteed nor undone.
  /// A shorter duration offers no snooze at all rather than an unreliable one.
  static const minSnoozeDuration = Duration(minutes: 1);

  /// Default [androidStaleAfter].
  ///
  /// Long enough that a reboot straddling the alarm still rings — a phone
  /// that restarts itself at 05:58 for a system update is back well inside
  /// this — and short enough that a phone switched on hours later stays
  /// quiet, where the user is already awake and a late ring is noise.
  static const defaultStaleAfter = _defaultStaleAfter;

  /// Value [androidStaleAfter] takes in JSON to mean never discard.
  ///
  /// A null field is omitted from the encoded map entirely, and a missing
  /// key has to keep meaning [defaultStaleAfter] so that alarms stored
  /// before this setting existed still get the new policy. Writing a
  /// sentinel instead keeps the two distinguishable across a restart. Part
  /// of the contract of [toJson], which is public.
  static const neverDiscardSentinel = -1;

  /// Unique identifier associated with the alarm. Cannot be 0 or -1.
  final int id;

  /// Date and time when the alarm will be triggered.
  final DateTime dateTime;

  /// Path to audio asset to be used as the alarm ringtone.
  ///
  /// If `null`, the device's default alarm sound will be used.
  ///
  /// Accepted formats:
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
  final String? assetAudioPath;

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

  /// Whether multiple alarms with different ids can be scheduled for the same
  /// second. When `false` (default), a new alarm scheduled for the same second
  /// as an existing one will replace it. When `true`, alarms with different ids
  /// can coexist even if they share the same second.
  ///
  /// Defaults to `false`.
  final bool allowSameSecondScheduling;

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
  /// A queued alarm is not affected; it rings next, as after a stop.
  ///
  /// Defaults to `true`. Has no effect on iOS.
  final bool androidStopAlarmOnTermination;

  /// If true, alarm audio routes to a connected earphone or Bluetooth device
  /// when one is present, falling back to the built-in speaker if not.
  /// Uses `STREAM_MUSIC` and `USAGE_MEDIA` instead of `STREAM_ALARM` and
  /// `USAGE_ALARM`, so the media volume slider controls the volume instead
  /// of the alarm slider.
  ///
  /// If false (default), audio is always forced to the built-in speaker
  /// via `USAGE_ALARM`, and the alarm volume slider applies.
  ///
  /// Has no effect on iOS. Defaults to `false`.
  final bool preferConnectedAudioDevice;

  /// Optional payload to be sent with the alarm. This can be used to pass
  /// additional data to the alarm handler.
  ///
  /// Caller is responsible for serializing and parsing the payload.
  final String? payload;

  /// How long the snooze action defers this alarm.
  ///
  /// **Android only.** When set, and when
  /// [NotificationSettings.androidSnoozeButton] gives it a label, the alarm
  /// notification offers a snooze that stops the current ring and re-registers
  /// the alarm this far ahead.
  ///
  /// Null, or anything under a minute, offers no snooze. The minimum exists
  /// because Android scheduling stops using `AlarmManager` for very short
  /// delays, and the fallback survives neither process death nor cancellation.
  final Duration? androidSnoozeDuration;

  /// How long past its due time an alarm found at boot is still worth
  /// ringing.
  ///
  /// **Android only.** A device that was off when an alarm was due rings it
  /// as soon as it boots. Past this much delay that is noise rather than a
  /// wake-up — an alarm set for 06:00 blaring at 08:00 tells the user
  /// nothing they cannot already see — so the alarm is discarded instead
  /// and reported as an [AlarmDropped] with cause
  /// [AlarmEventCause.staleAtBoot].
  ///
  /// Defaults to [defaultStaleAfter]. **An explicit null never discards**,
  /// which is the behaviour of 5.10.0 and earlier, for an alarm that has to
  /// ring however late. Omitting it and asking for null are deliberately
  /// different things.
  ///
  /// Cannot be shorter than the grace period [Alarm.checkAlarm] already
  /// gives an alarm that is due but not yet audible, or Dart would spare an
  /// alarm the boot path had discarded; [Alarm.set] throws
  /// [AlarmErrorCode.invalidArguments] instead of letting the two disagree.
  @JsonKey(fromJson: _staleAfterFromJson, toJson: _staleAfterToJson)
  final Duration? androidStaleAfter;

  /// Whether to arm this alarm as an alarm clock.
  ///
  /// **Android only.** Uses `AlarmManager.setAlarmClock`, which Doze and OEM
  /// battery savers exempt and leave idle for shortly before the alarm. The
  /// alarm also becomes the system's next alarm: a status bar icon, the time in
  /// Quick Settings and on the lock screen, and readable by other apps. Set to
  /// `false` for an alarm that should not be advertised that way; it is then
  /// armed with `setExactAndAllowWhileIdle`, as before 5.14.0.
  ///
  /// Without the exact alarm permission, both fall back to an inexact alarm.
  ///
  /// Defaults to `true`. Has no effect on iOS.
  final bool androidAlarmClock;

  /// Reads [androidStaleAfter], recovering rather than throwing.
  ///
  /// Nothing between [Alarm.init] and the storage read catches, so throwing
  /// here would cost the user every stored alarm rather than the one malformed
  /// field. An unusable value falls back to [defaultStaleAfter], the same
  /// answer an absent key gives.
  static Duration? _staleAfterFromJson(Object? value) {
    // Integral doubles are accepted: a re-encoder can turn 900000 into
    // 900000.0, while 1.5 would truncate to a one-microsecond window.
    if (value is! num || !value.isFinite || value % 1 != 0) {
      _log.warning('Unusable androidStaleAfter $value; using the default.');
      return defaultStaleAfter;
    }
    final micros = value.toInt();
    if (micros == neverDiscardSentinel) return null;
    if (micros < 0) {
      _log.warning('Unusable androidStaleAfter $micros; using the default.');
      return defaultStaleAfter;
    }
    return Duration(microseconds: micros);
  }

  /// Writes [androidStaleAfter]. The non-null return also stops
  /// `json_serializable` omitting the key, which is what would lose a null.
  static int _staleAfterToJson(Duration? value) =>
      value?.inMicroseconds ?? neverDiscardSentinel;

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
        allowSameSecondScheduling: allowSameSecondScheduling,
        iOSBackgroundAudio: iOSBackgroundAudio,
        androidStopAlarmOnTermination: androidStopAlarmOnTermination,
        preferConnectedAudioDevice: preferConnectedAudioDevice,
        androidSnoozeDurationMillis: androidSnoozeDuration?.inMilliseconds,
        androidStaleAfterMillis: androidStaleAfter?.inMilliseconds,
        androidAlarmClock: androidAlarmClock,
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
    @Deprecated('This parameter is ignored. Use volumeSettings instead.')
    double? volume,
    @Deprecated('This parameter is ignored. Use volumeSettings instead.')
    bool? volumeEnforced,
    @Deprecated('This parameter is ignored. Use volumeSettings instead.')
    double? fadeDuration,
    @Deprecated('This parameter is ignored. Use volumeSettings instead.')
    List<double>? fadeStopTimes,
    @Deprecated('This parameter is ignored. Use volumeSettings instead.')
    List<double>? fadeStopVolumes,
    @Deprecated('This parameter is ignored. Use notificationSettings instead.')
    String? notificationTitle,
    @Deprecated('This parameter is ignored. Use notificationSettings instead.')
    String? notificationBody,
    bool? warningNotificationOnKill,
    bool? androidFullScreenIntent,
    bool? allowAlarmOverlap,
    bool? allowSameSecondScheduling,
    bool? iOSBackgroundAudio,
    bool? androidStopAlarmOnTermination,
    bool? preferConnectedAudioDevice,
    String? Function()? payload,
    Duration? Function()? androidSnoozeDuration,
    Duration? Function()? androidStaleAfter,
    bool? androidAlarmClock,
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
      allowSameSecondScheduling:
          allowSameSecondScheduling ?? this.allowSameSecondScheduling,
      iOSBackgroundAudio: iOSBackgroundAudio ?? this.iOSBackgroundAudio,
      androidStopAlarmOnTermination:
          androidStopAlarmOnTermination ?? this.androidStopAlarmOnTermination,
      preferConnectedAudioDevice:
          preferConnectedAudioDevice ?? this.preferConnectedAudioDevice,
      // The function wrapper allows callers to clear the payload by
      // explicitly returning null.
      payload: payload != null ? payload() : this.payload,
      // Wrapped like payload so a caller can remove an existing snooze by
      // returning null, which a plain nullable parameter cannot express.
      androidSnoozeDuration: androidSnoozeDuration != null
          ? androidSnoozeDuration()
          : this.androidSnoozeDuration,
      // Wrapped for the same reason, and here null is a real choice rather
      // than an absence: it means never discard.
      androidStaleAfter: androidStaleAfter != null
          ? androidStaleAfter()
          : this.androidStaleAfter,
      androidAlarmClock: androidAlarmClock ?? this.androidAlarmClock,
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
        allowSameSecondScheduling,
        iOSBackgroundAudio,
        androidStopAlarmOnTermination,
        preferConnectedAudioDevice,
        payload,
        androidSnoozeDuration,
        androidStaleAfter,
        androidAlarmClock,
      ];
}
