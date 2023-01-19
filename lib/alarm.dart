import 'dart:io';

import 'package:alarm/alarm_platform_interface.dart';
import 'package:alarm/android_alarm.dart';
import 'package:alarm/notification.dart';
import 'package:alarm/storage.dart';

class Alarm {
  /// To get the singleton instance
  static AlarmPlatform get platform => AlarmPlatform.instance;

  /// To know if it's iOS device
  static bool get iOS => Platform.isIOS;

  /// To know if it's Android device
  static bool get android => Platform.isAndroid;

  /// Initialize Alarm services
  static Future<void> init() => Future.wait([
        if (android) AndroidAlarm.init(),
        Notification.instance.init(),
        Storage.init(),
      ]);

  /// Schedule alarm for [alarmDateTime]
  ///
  /// [onRing] will be called when alarm is triggered at [alarmDateTime]
  ///
  /// [assetAudio] is the audio asset you want to use as the alarm ringtone.
  /// For iOS, you need to drag and drop your asset(s) to your `Runner` folder
  /// in Xcode and make sure 'Copy items if needed' is checked.
  /// Can also be an URL.
  ///
  /// If you want to show a notification when alarm is triggered,
  /// [notifTitle] and [notifBody] must not be null
  static Future<bool> set({
    required DateTime alarmDateTime,
    void Function()? onRing,
    required String assetAudio,
    String? notifTitle,
    String? notifBody,
  }) async {
    final loopAudio = Storage.getBool('loop') ?? true;

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

  /// If set to `true`, the alarm audio will repeat indefinitely
  /// until it is stopped.
  ///
  /// By default, the loop mode is enabled.
  static Future<void> loop(bool loop) => Storage.setBool('loop', loop);

  /// Sets a notification that will show when alarm starts ringing.
  static Future<void> setNotificationOnRing(
    String title,
    String body,
  ) =>
      Storage.setNotificationContentOnRing(title, body);

  /// When the app is killed, all the processes are terminated
  /// so the alarm may never ring. To warn the user, a notification
  /// is shown at the moment he kills the app.
  /// This methods allows you to customize the notification content.
  ///
  /// [title] default value is `Your alarm may not ring`
  ///
  /// [body] default value is `You killed the app. Please reopen so your alarm can ring.`
  static Future<void> setNotificationOnAppKillContent(
    String title,
    String body,
  ) =>
      Storage.setNotificationContentOnAppKill(title, body);

  /// Stop alarm
  static Future<bool> stop() async {
    if (iOS) {
      Notification.instance.cancel();
      return await platform.stopAlarm();
    }
    return await AndroidAlarm.stop();
  }

  /// Whether the alarm is ringing
  static Future<bool> isRinging() => platform.checkIfRinging();
}
