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
      AlarmNotification.instance.init(),
      AlarmStorage.init(),
    ]);
    checkAlarm();
  }

  /// Checks if some alarms were set on previous session.
  /// If it's the case then reschedules them.
  static Future<void> checkAlarm() async {
    final alarms = AlarmStorage.getSavedAlarms();

    for (final alarm in alarms) {
      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        set(settings: alarm);
      } else {
        await AlarmStorage.unsaveAlarm(alarm.id);
      }
    }
  }

  /// Schedules an alarm with given [settings].
  static Future<bool> set({required AlarmSettings settings}) async {
    await AlarmStorage.saveAlarm(settings);
    await AlarmNotification.instance.cancel(settings.id);

    if (settings.enableNotificationOnKill) {
      await AlarmNotification.instance.requestPermission();
    }

    if (iOS) {
      final assetAudio = settings.assetAudioPath.split('/').last;
      return IOSAlarm.setAlarm(
        settings.id,
        settings.dateTime,
        () => ringStream.add(settings),
        assetAudio,
        settings.loopAudio,
        settings.fadeDuration,
        settings.notificationTitle,
        settings.notificationBody,
        settings.enableNotificationOnKill,
      );
    }

    return await AndroidAlarm.set(
      settings.id,
      settings.dateTime,
      () => ringStream.add(settings),
      settings.assetAudioPath,
      settings.loopAudio,
      settings.fadeDuration,
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
      AlarmStorage.setNotificationContentOnAppKill(title, body);

  /// Stops alarm.
  static Future<bool> stop(int id) async {
    await AlarmStorage.unsaveAlarm(id);

    if (iOS) {
      AlarmNotification.instance.cancel(id);
      return await IOSAlarm.stopAlarm(id);
    }
    return await AndroidAlarm.stop(id);
  }

  /// Whether the alarm is ringing.
  static Future<bool> isRinging(int id) => IOSAlarm.checkIfRinging(id);

  /// Whether an alarm is set.
  static bool hasAlarm() => AlarmStorage.hasAlarm();

  static List<AlarmSettings> getAlarms() => AlarmStorage.getSavedAlarms();
}
