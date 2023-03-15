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
        set(alarmSettings: alarm);
      } else {
        await AlarmStorage.unsaveAlarm(alarm.id);
      }
    }
  }

  /// Schedules an alarm with given [alarmSettings].
  ///
  /// If you set an alarm for the same [dateTime] as an existing one,
  /// the new alarm will replace the existing one.
  static Future<bool> set({required AlarmSettings alarmSettings}) async {
    for (final alarm in Alarm.getAlarms()) {
      if (alarm.dateTime.hour == alarmSettings.dateTime.hour &&
          alarm.dateTime.minute == alarmSettings.dateTime.minute) {
        Alarm.stop(alarm.id);
      }
    }

    await AlarmStorage.saveAlarm(alarmSettings);
    await AlarmNotification.instance.cancel(alarmSettings.id);

    if (alarmSettings.enableNotificationOnKill) {
      await AlarmNotification.instance.requestPermission();
    }

    if (iOS) {
      final assetAudio = alarmSettings.assetAudioPath.split('/').last;
      return IOSAlarm.setAlarm(
        alarmSettings.id,
        alarmSettings.dateTime,
        () => ringStream.add(alarmSettings),
        assetAudio,
        alarmSettings.loopAudio,
        alarmSettings.fadeDuration,
        alarmSettings.notificationTitle,
        alarmSettings.notificationBody,
        alarmSettings.enableNotificationOnKill,
      );
    }

    return await AndroidAlarm.set(
      alarmSettings.id,
      alarmSettings.dateTime,
      () => ringStream.add(alarmSettings),
      alarmSettings.assetAudioPath,
      alarmSettings.loopAudio,
      alarmSettings.fadeDuration,
      alarmSettings.notificationTitle,
      alarmSettings.notificationBody,
      alarmSettings.enableNotificationOnKill,
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

    AlarmNotification.instance.cancel(id);

    return iOS ? await IOSAlarm.stopAlarm(id) : await AndroidAlarm.stop(id);
  }

  /// Whether the alarm is ringing.
  static Future<bool> isRinging(int id) => IOSAlarm.checkIfRinging(id);

  /// Whether an alarm is set.
  static bool hasAlarm() => AlarmStorage.hasAlarm();

  static List<AlarmSettings> getAlarms() => AlarmStorage.getSavedAlarms();
}
