import 'dart:io';

import 'package:alarm/alarm_platform_interface.dart';
import 'package:alarm/android_alarm.dart';
import 'package:alarm/notification.dart';

class Alarm {
  static AlarmPlatform get platform => AlarmPlatform.instance;

  static bool get iOS => Platform.isIOS;
  static bool get android => Platform.isAndroid;

  /// Initialize Alarm service
  static Future<void> init() async {
    if (android) await AndroidAlarm.init();
    await Notification.instance.init();
  }

  /// Schedule alarm for [alarmDateTime]
  ///
  /// [onRing] will be called when alarm is triggered at [alarmDateTime]
  ///
  /// [assetAudio] is the audio asset you want to use as the alarm ringtone.
  /// If null, the default ringtone will be used
  /// For iOS, you need to drag and drop your asset(s) to your `Runner` folder
  /// in Xcode and make sure 'Copy items if needed' is checked
  ///
  /// If [loopAudio] is set to true, [assetAudio] will repeat indefinitely
  /// until it is stopped. Default value is false.
  ///
  /// If you want to show a notification when alarm is triggered,
  /// [notifTitle] and [notifBody] must not be null
  static Future<bool> set({
    required DateTime alarmDateTime,
    void Function()? onRing,
    required String assetAudio,
    bool loopAudio = false,
    String? notifTitle,
    String? notifBody,
  }) async {
    if (iOS) {
      assetAudio = assetAudio.split('/').last;
      return platform.setAlarm(
        alarmDateTime,
        onRing,
        assetAudio,
        loopAudio,
        notifTitle,
        notifBody,
      );
    }

    return await AndroidAlarm.set(
      alarmDateTime,
      onRing,
      assetAudio,
      loopAudio,
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

  /// Check if alarm is ringing
  static Future<bool> isRinging() => platform.checkIfRinging();
}
