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
  /// [notifTitle] and [notifBody] must not be null
  static Future<bool> set({
    required DateTime alarmDateTime,
    void Function()? onRing,
    String? assetAudio,
    String? notifTitle,
    String? notifBody,
  }) async {
    if (iOS) {
      return platform.setAlarm(
        alarmDateTime,
        onRing,
        assetAudio ?? defaultAlarmAudio,
        notifTitle,
        notifBody,
      );
    }

    return await AndroidAlarm.set(
      alarmDateTime,
      onRing,
      assetAudio ?? defaultAlarmAudio,
      notifTitle,
      notifBody,
    );
  }

  /// Stop alarm
  static Future<bool> stop() async {
    if (iOS) {
      Notification.instance.cancel();
      return await platform.stopAlarm();
    }
    return await AndroidAlarm.stop();
  }
}
