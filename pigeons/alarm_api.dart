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
class AlarmSettingsWire {
  const AlarmSettingsWire({
    required this.id,
    required this.millisecondsSinceEpoch,
    required this.assetAudioPath,
    required this.volumeSettings,
    required this.notificationSettings,
    this.loopAudio = true,
    this.vibrate = true,
    this.warningNotificationOnKill = true,
    this.androidFullScreenIntent = true,
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
    this.stopButton,
    this.icon,
  });

  final String title;
  final String body;
  final String? stopButton;
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
