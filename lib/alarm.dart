import 'dart:io';

import 'package:alarm/alarm_platform_interface.dart';
import 'package:alarm/android_alarm.dart';

class Alarm {
  static AlarmPlatform get platform => AlarmPlatform.instance;
  static const String defaultAlarmAudio = 'sample.mp3';

  static bool get iOS => Platform.isIOS;

  /// Initialize Alarm service
  ///
  /// Not necessary if app is iOS only
  static Future<void> init() async {
    if (!iOS) await AndroidAlarm.init();
  }

  /// Schedule alarm for [alarmDateTime]
  static Future<bool> set({
    required DateTime alarmDateTime,
    String? assetAudio,
  }) async {
    if (iOS) {
      return platform.setAlarm(alarmDateTime, assetAudio ?? defaultAlarmAudio);
    }

    return await AndroidAlarm.set(
      alarmDateTime,
      assetAudio ?? defaultAlarmAudio,
    );
  }

  /// Stop alarm
  static Future<bool> stop() async {
    if (iOS) {
      return await platform.stopAlarm();
    }
    return await AndroidAlarm.stop();
  }

  /// Snooze alarm
  static Future<bool> snooze(DateTime alarmDateTime, String? assetAudio) async {
    if (iOS) {
      return await platform.setAlarm(
        alarmDateTime,
        assetAudio ?? defaultAlarmAudio,
      );
    }
    return await AndroidAlarm.snooze();
  }
}
