export 'package:alarm/model/alarm_settings.dart';

import 'dart:async';
import 'dart:io';

import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/src/ios_alarm.dart';
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

  /// Checks if an alarm was set on another session.
  /// If it's the case, reschedules it.
  static Future<void> checkAlarm() async {
    final alarm = Storage.getSavedAlarm();
    if (alarm == null) return;

    final now = DateTime.now();
    if (alarm.dateTime.isAfter(now)) {
      set(settings: alarm);
    } else {
      await Storage.unsaveAlarm();
    }
  }

  /// Schedules an alarm with given [settings].
  static Future<bool> set({required AlarmSettings settings}) async {
    await Storage.saveAlarm(settings);
    await Notification.instance.cancel();

    if (settings.enableNotificationOnKill) {
      await Notification.instance.requestPermission();
    }

    if (iOS) {
      final assetAudio = settings.assetAudioPath.split('/').last;
      return IOSAlarm.setAlarm(
        settings.dateTime,
        () => ringStream.add(settings),
        assetAudio,
        settings.loopAudio,
        settings.notificationTitle,
        settings.notificationBody,
        settings.enableNotificationOnKill,
      );
    }

    return await AndroidAlarm.set(
      settings.dateTime,
      () => ringStream.add(settings),
      settings.assetAudioPath,
      settings.loopAudio,
      settings.notificationTitle,
      settings.notificationBody,
      settings.enableNotificationOnKill,
    );
  }

  /// When the app is killed, all the processes are terminated
  /// so the alarm may never ring. By default, to warn the user, a notification
  /// is shown at the moment he kills the app.
  /// This methods allows you to customize this notification content.
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
    await Storage.unsaveAlarm();

    if (iOS) {
      Notification.instance.cancel();
      return await IOSAlarm.stopAlarm();
    }
    return await AndroidAlarm.stop();
  }

  /// Whether the alarm is ringing.
  static Future<bool> isRinging() => IOSAlarm.checkIfRinging();

  /// Whether an alarm is set.
  static bool hasAlarm() => Storage.hasAlarm();
}
