import 'dart:io';

import 'package:alarm/alarm_platform_interface.dart';
import 'package:alarm/android_alarm.dart';
import 'package:alarm/notification.dart';

class Alarm {
  static AlarmPlatform get platform => AlarmPlatform.instance;
  static const String defaultAlarmAudio = 'sample.mp3';

  static bool get iOS => Platform.isIOS;

  /// Initialize Alarm service
  static Future<void> init() async {
    if (!iOS) await AndroidAlarm.init();
    await Notification.instance.init();
  }

  /// Schedule alarm for [alarmDateTime]
  ///
  /// If you want to show a notification when alarm is triggered,
  /// [notifTitle] and [notifBody] must be defined
  static Future<bool> set({
    required DateTime alarmDateTime,
    String? assetAudio,
    String? notifTitle,
    String? notifBody,
  }) async {
    if (iOS) {
      return platform.setAlarm(alarmDateTime, assetAudio ?? defaultAlarmAudio);
    }

    return await AndroidAlarm.set(
      alarmDateTime,
      assetAudio ?? defaultAlarmAudio,
      notifTitle,
      notifBody,
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
