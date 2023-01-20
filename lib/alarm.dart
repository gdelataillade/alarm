import 'dart:async';
import 'dart:io';

import 'package:alarm/src/ios_alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/src/android_alarm.dart';
import 'package:alarm/service/notification.dart';
import 'package:alarm/service/storage.dart';

class Alarm {
  /// Whether it's iOS device.
  static bool get iOS => Platform.isIOS;

  /// Whether it's Android device.
  static bool get android => Platform.isAndroid;

  /// Stream of the ringing status.
  static final ringStream = StreamController<AlarmSettings>();

  /// Checks if an alarm is set.
  static void checkAlarm() {
    final currentAlarm = Storage.getCurrentAlarm();
    if (currentAlarm == null) return;
    final now = DateTime.now();
    if (currentAlarm.alarmDateTime.isBefore(now)) {
      set(settings: currentAlarm);
    }
  }

  /// Initializes Alarm services.
  ///
  /// Also calls `checkAlarm` that will reschedule the alarm is app was killed
  /// while an alarm was set.
  static Future<void> init() async {
    await Future.wait([
      if (android) AndroidAlarm.init(),
      Notification.instance.init(),
      Storage.init(),
    ]);
    checkAlarm();
  }

  /// Schedules alarm with given [settings].
  static Future<bool> set({required AlarmSettings settings}) async {
    await Storage.setCurrentAlarm(settings);

    if (iOS) {
      final assetAudio = settings.assetAudioPath.split('/').last;
      return IOSAlarm.setAlarm(
        settings.alarmDateTime,
        () => ringStream.add(settings),
        assetAudio,
        settings.loopAudio,
        settings.notificationTitle,
        settings.notificationBody,
      );
    }

    return await AndroidAlarm.set(
      settings.alarmDateTime,
      () => ringStream.add(settings),
      settings.assetAudioPath,
      settings.loopAudio,
      settings.notificationTitle,
      settings.notificationBody,
    );
  }

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

  /// Stops alarm.
  static Future<bool> stop() async {
    if (iOS) {
      Notification.instance.cancel();
      return await IOSAlarm.stopAlarm();
    }
    return await AndroidAlarm.stop();
  }

  /// Whether the alarm is ringing.
  static Future<bool> isRinging() => IOSAlarm.checkIfRinging();
}
