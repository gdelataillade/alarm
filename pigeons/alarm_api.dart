import 'package:pigeon/pigeon.dart';

// After modifying this file run:
// dart run pigeon --input pigeons/alarm_api.dart && dart format .

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/platform_bindings.g.dart',
    dartPackageName: 'alarm',
    swiftOut: 'ios/alarm/Sources/alarm/generated/FlutterBindings.g.swift',
    kotlinOut:
        'android/src/main/kotlin/com/gdelataillade/alarm/generated/FlutterBindings.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.gdelataillade.alarm.generated',
    ),
  ),
)
class AlarmSettingsWire {
  const AlarmSettingsWire({
    required this.id,
    required this.millisecondsSinceEpoch,
    required this.assetAudioPath,
    required this.volumeSettings,
    required this.notificationSettings,
    required this.loopAudio,
    required this.vibrate,
    required this.warningNotificationOnKill,
    required this.androidFullScreenIntent,
    required this.allowAlarmOverlap,
    required this.allowSameSecondScheduling,
    required this.iOSBackgroundAudio,
    required this.androidStopAlarmOnTermination,
    required this.preferConnectedAudioDevice,
    required this.androidSnoozeDurationMillis,
  });

  final int id;
  final int millisecondsSinceEpoch;
  final String? assetAudioPath;
  final VolumeSettingsWire volumeSettings;
  final NotificationSettingsWire notificationSettings;
  final bool loopAudio;
  final bool vibrate;
  final bool warningNotificationOnKill;
  final bool androidFullScreenIntent;
  final bool allowAlarmOverlap;
  final bool allowSameSecondScheduling;
  final bool iOSBackgroundAudio;
  final bool androidStopAlarmOnTermination;
  final bool preferConnectedAudioDevice;

  /// How long the snooze action defers the alarm, in milliseconds.
  ///
  /// Null, or anything below one minute, offers no snooze. The floor exists
  /// because Android scheduling falls back to a plain `Handler.postDelayed`
  /// below a few seconds, which survives neither process death nor
  /// cancellation. Android only.
  final int? androidSnoozeDurationMillis;
}

class VolumeSettingsWire {
  const VolumeSettingsWire({
    required this.volume,
    required this.fadeDurationMillis,
    required this.fadeSteps,
    required this.volumeEnforced,
    required this.showSystemUI,
  });

  final double? volume;
  final int? fadeDurationMillis;
  final List<VolumeFadeStepWire> fadeSteps;
  final bool volumeEnforced;
  final bool showSystemUI;
}

class VolumeFadeStepWire {
  const VolumeFadeStepWire({
    required this.timeMillis,
    required this.volume,
  });

  final int timeMillis;
  final double volume;
}

class NotificationSettingsWire {
  const NotificationSettingsWire({
    required this.title,
    required this.body,
    required this.stopButton,
    required this.icon,
    required this.iconColorAlpha,
    required this.iconColorRed,
    required this.iconColorGreen,
    required this.iconColorBlue,
    required this.keepNotificationAfterAlarmEnds,
    required this.androidSnoozeButton,
    required this.androidStopAlarmOnDismiss,
  });

  final String title;
  final String body;
  final String? stopButton;
  final String? icon;
  final double? iconColorAlpha;
  final double? iconColorRed;
  final double? iconColorGreen;
  final double? iconColorBlue;
  final bool keepNotificationAfterAlarmEnds;

  /// Label for the snooze action. Null omits the action.
  ///
  /// Only shown when [AlarmSettingsWire.androidSnoozeDurationMillis] also
  /// gives it a usable duration; a label alone describes nothing the platform
  /// can perform. Android only.
  final String? androidSnoozeButton;

  /// Whether swiping the notification away also stops the alarm. Android only.
  final bool androidStopAlarmOnDismiss;
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
  @async
  void setAlarm({required AlarmSettingsWire alarmSettings});

  @async
  void stopAlarm({required int alarmId});

  @async
  void stopAll();

  bool isRinging({required int? alarmId});

  void setWarningNotificationOnKill({
    required String title,
    required String body,
  });

  void disableWarningNotificationOnKill();

  /// Lists snoozes the host has recorded but Dart has not yet applied.
  ///
  /// A snooze is normally taken with no engine running: the notification is
  /// native and a full screen intent starts the process without starting
  /// Flutter, so [AlarmTriggerApi.alarmSnoozed] reaches nobody. The host holds
  /// a marker until Dart has durably applied it.
  ///
  /// Reading is **not** destructive — the marker survives until
  /// [acknowledgeSnooze] confirms Dart wrote the new time. A read that is
  /// followed by a crash therefore loses nothing.
  @async
  List<PendingSnoozeWire> getPendingSnoozes();

  /// Drops the marker for [alarmId], but only if it still records exactly
  /// [nextRingAtMillis].
  ///
  /// Matching on the timestamp as well as the id means a late acknowledgement
  /// for an earlier snooze cannot discard a newer one taken for the same
  /// alarm in the meantime.
  @async
  void acknowledgeSnooze({
    required int alarmId,
    required int nextRingAtMillis,
  });
}

/// A snooze the host recorded and Dart has not yet applied.
class PendingSnoozeWire {
  const PendingSnoozeWire({
    required this.alarmId,
    required this.millisecondsSinceEpoch,
  });

  final int alarmId;
  final int millisecondsSinceEpoch;
}

@FlutterApi()
abstract class AlarmTriggerApi {
  @async
  void alarmRang(int alarmId);

  @async
  void alarmStopped(int alarmId);

  /// An alarm was deferred on the host side and re-registered for
  /// [millisecondsSinceEpoch].
  ///
  /// Distinct from [alarmStopped] because the alarm is still owed: reporting a
  /// snooze as a stop would tell the application the user dismissed something
  /// they asked to be reminded of again.
  @async
  void alarmSnoozed(int alarmId, int millisecondsSinceEpoch);
}
