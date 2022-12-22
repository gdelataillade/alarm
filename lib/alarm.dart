import 'alarm_platform_interface.dart';

class Alarm {
  static AlarmPlatform get platform => AlarmPlatform.instance;

  /// Set alarm
  static Future<bool> setAlarm(
    DateTime alarmDateTime,
    String assetAudio,
  ) async =>
      platform.setAlarm(alarmDateTime, assetAudio);

  /// Stop alarm
  static Future<bool> stopAlarm() async => platform.stopAlarm();
}
