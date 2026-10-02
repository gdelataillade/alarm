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
    required this.androidStaleAfterMillis,
    required this.androidAlarmClock,
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

  /// How long past its due time an alarm found at boot is still worth
  /// ringing, in milliseconds.
  ///
  /// Null means never discard. Absent from an alarm stored before the
  /// setting existed, which reads as the default rather than as null.
  /// Android only.
  final int? androidStaleAfterMillis;

  /// Whether to arm with `setAlarmClock`. Android only.
  final bool androidAlarmClock;
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

  AlarmStateWire getAlarmState({required int alarmId});

  void setWarningNotificationOnKill({
    required String title,
    required String body,
  });

  void disableWarningNotificationOnKill();

  /// Lists changes the host has made to alarms that Dart has not yet applied.
  ///
  /// These decisions are normally taken with no engine running: the
  /// notification is native, a full screen intent starts the process without
  /// starting Flutter, and `BootReceiver` runs before any app code, so
  /// [AlarmTriggerApi.alarmEvent] reaches nobody. The host holds a marker until
  /// Dart has durably applied it.
  ///
  /// Reading is **not** destructive — a marker survives until
  /// [acknowledgeAlarmEvent] confirms Dart applied it. A read that is followed
  /// by a crash therefore loses nothing.
  @async
  List<AlarmEventWire> getPendingAlarmEvents();

  /// Drops the marker for [alarmId], but only if it still records exactly
  /// [recordedAtMillis].
  ///
  /// Matching on the timestamp as well as the id means a late acknowledgement
  /// for an earlier event cannot discard a newer one recorded for the same
  /// alarm in the meantime.
  @async
  void acknowledgeAlarmEvent({
    required int alarmId,
    required int recordedAtMillis,
  });
}

/// What the host did to an alarm without the application asking.
///
/// Dart's handling depends only on this: [moved] rewrites the stored time,
/// [dropped] removes the alarm. The [AlarmEventCauseWire] is for the app.
enum AlarmEventVerbWire {
  /// The alarm is still owed and is now registered for a different time.
  moved,

  /// The alarm is gone and will not ring.
  dropped,
}

/// Why the host changed an alarm.
enum AlarmEventCauseWire {
  /// The user deferred the alarm from the notification or the ring screen.
  snooze,

  /// The platform refused to let the ring start.
  ///
  /// Android forbids starting a `mediaPlayback` foreground service from
  /// `BOOT_COMPLETED`, and the refusal follows the attribution rather than the
  /// caller, so an ordinary alarm delivered inside the boot window is refused
  /// too. The alarm is normally re-armed just past that window, because ringing
  /// late beats not ringing; it is only dropped when the retry is refused as
  /// well, which means the boot window was not the cause.
  platformRefusal,

  /// The alarm's time had already passed while the device was off, so it was
  /// discarded at boot rather than sounded hours late.
  staleAtBoot,
}

/// What the host is doing with an alarm right now.
enum AlarmStateWire {
  /// Neither ringing nor queued.
  inactive,

  /// Currently playing.
  ringing,

  /// Waiting behind another ringing alarm. Only Android reports it.
  queued,
}

/// A change the host made to an alarm that Dart has not yet applied.
class AlarmEventWire {
  const AlarmEventWire({
    required this.alarmId,
    required this.verb,
    required this.cause,
    required this.atMillis,
    required this.recordedAtMillis,
  });

  final int alarmId;
  final AlarmEventVerbWire verb;
  final AlarmEventCauseWire cause;

  /// For [AlarmEventVerbWire.moved], when the alarm now rings. For
  /// [AlarmEventVerbWire.dropped], when it should have rung.
  final int atMillis;

  /// When the host recorded this, used to acknowledge exactly this event.
  final int recordedAtMillis;
}

@FlutterApi()
abstract class AlarmTriggerApi {
  @async
  void alarmRang(int alarmId);

  @async
  void alarmStopped(int alarmId);

  /// The host moved or dropped an alarm on its own.
  ///
  /// Distinct from [alarmStopped], which means the user resolved the alarm. A
  /// deferral reported as a stop would tell the application it was dismissed;
  /// a discard reported as a stop would hide that the alarm never rang.
  ///
  /// Only reaches Dart when an engine happens to be attached. The durable
  /// record is the host's marker, drained by `AlarmApi.getPendingAlarmEvents`,
  /// so this call is an optimisation rather than the contract.
  @async
  void alarmEvent(AlarmEventWire event);
}
