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
    required this.iOSBackgroundAudio,
    required this.androidStopAlarmOnTermination,
  });

  final int id;
  final int millisecondsSinceEpoch;
  final String assetAudioPath;
  final VolumeSettingsWire volumeSettings;
  final NotificationSettingsWire notificationSettings;
  final bool loopAudio;
  final bool vibrate;
  final bool warningNotificationOnKill;
  final bool androidFullScreenIntent;
  final bool allowAlarmOverlap;
  final bool iOSBackgroundAudio;
  final bool androidStopAlarmOnTermination;
}

class VolumeSettingsWire {
  const VolumeSettingsWire({
    required this.volume,
    required this.fadeDurationMillis,
    required this.fadeSteps,
    required this.volumeEnforced,
  });

  final double? volume;
  final int? fadeDurationMillis;
  final List<VolumeFadeStepWire> fadeSteps;
  final bool volumeEnforced;
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
  });

  final String title;
  final String body;
  final String? stopButton;
  final String? icon;
  final double? iconColorAlpha;
  final double? iconColorRed;
  final double? iconColorGreen;
  final double? iconColorBlue;
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
}

@FlutterApi()
abstract class AlarmTriggerApi {
  @async
  void alarmRang(int alarmId);

  @async
  void alarmStopped(int alarmId);
}
