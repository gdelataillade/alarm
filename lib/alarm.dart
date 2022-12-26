import 'alarm_platform_interface.dart';

class Alarm {
  static AlarmPlatform get platform => AlarmPlatform.instance;
  static const String defaultAlarmAudio = 'sample.mp3';

  /// Set alarm
  static Future<bool> set({
    required DateTime alarmDateTime,
    String? assetAudio,
  }) async =>
      platform.setAlarm(alarmDateTime, assetAudio ?? defaultAlarmAudio);

  /// Stop alarm
  static Future<bool> stop() async => platform.stopAlarm();

  /// Snooze alarm
  static Future<bool> snooze({
    required DateTime alarmDateTime,
    String assetAudio = defaultAlarmAudio,
  }) async {
    final res = await set(
      alarmDateTime: alarmDateTime,
      assetAudio: assetAudio,
    );
    return res;
  }
}
