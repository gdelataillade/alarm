// ignore_for_file: avoid_print

export 'package:alarm/model/alarm_settings.dart';
import 'dart:async';

import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:alarm/src/android_alarm.dart';
import 'package:alarm/service/notification.dart';
import 'package:alarm/service/storage.dart';
import 'package:flutter/foundation.dart';

/// Custom print function designed for Alarm plugin.
DebugPrintCallback alarmPrint = debugPrintThrottled;

class Alarm {
  /// Whether it's iOS device.
  static bool get iOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether it's Android device.
  static bool get android => defaultTargetPlatform == TargetPlatform.android;

  /// Stream of the ringing status.
  static final ringStream = StreamController<AlarmSettings>();

  /// Initializes Alarm services.
  ///
  /// Also calls [checkAlarm] that will reschedule alarms that were set before
  /// app termination.
  ///
  /// Set [showDebugLogs] to `false` to hide all the logs from the plugin.
  static Future<void> init({bool showDebugLogs = true}) async {
    alarmPrint = (String? message, {int? wrapWidth}) {
      if (kDebugMode && showDebugLogs) {
        print("[Alarm] $message");
      }
    };

    await Future.wait([
      if (android) AndroidAlarm.init(),
      AlarmNotification.instance.init(),
      AlarmStorage.init(),
    ]);
    await checkAlarm();
  }

  /// Checks if some alarms were set on previous session.
  /// If it's the case then reschedules them.
  static Future<void> checkAlarm() async {
    final alarms = AlarmStorage.getSavedAlarms();

    for (final alarm in alarms) {
      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        await set(alarmSettings: alarm);
      } else {
        await AlarmStorage.unsaveAlarm(alarm.id);
      }
    }
  }

  /// Schedules an alarm with given [alarmSettings].
  ///
  /// If you set an alarm for the same [dateTime] as an existing one,
  /// the new alarm will replace the existing one.
  ///
  /// Also, schedules notification if [notificationTitle] and [notificationBody]
  /// are not null nor empty.
  static Future<bool> set({required AlarmSettings alarmSettings}) async {
    for (final alarm in Alarm.getAlarms()) {
      if (alarm.id == alarmSettings.id ||
          (alarm.dateTime.day == alarmSettings.dateTime.day &&
              alarm.dateTime.hour == alarmSettings.dateTime.hour &&
              alarm.dateTime.minute == alarmSettings.dateTime.minute)) {
        await Alarm.stop(alarm.id);
      }
    }

    await AlarmStorage.saveAlarm(alarmSettings);

    if (alarmSettings.notificationTitle != null && alarmSettings.notificationBody != null) {
      if (alarmSettings.notificationTitle!.isNotEmpty &&
          alarmSettings.notificationBody!.isNotEmpty) {
        await AlarmNotification.instance.scheduleAlarmNotif(
          id: alarmSettings.id,
          dateTime: alarmSettings.dateTime,
          locationName: alarmSettings.notificationTimeZoneId,
          title: alarmSettings.notificationTitle!,
          body: alarmSettings.notificationBody!,
        );
      }
    }

    if (alarmSettings.enableNotificationOnKill) {
      await AlarmNotification.instance.requestPermission();
    }

    if (!alarmSettings.assetAudioPath.contains('.')) {
      alarmPrint(
        'Error: provided asset audio file do not have extension: $alarmSettings.assetAudioPath',
      );
    }

    if (iOS) {
      final assetAudio = alarmSettings.assetAudioPath.split('/').last;
      return IOSAlarm.setAlarm(
        alarmSettings.id,
        alarmSettings.dateTime,
        () => ringStream.add(alarmSettings),
        assetAudio,
        alarmSettings.loopAudio,
        alarmSettings.vibrate,
        alarmSettings.fadeDuration,
        alarmSettings.notificationTitle,
        alarmSettings.notificationBody,
        alarmSettings.enableNotificationOnKill,
      );
    }
    if (android) {
      return await AndroidAlarm.set(
        alarmSettings.id,
        alarmSettings.dateTime,
        () => ringStream.add(alarmSettings),
        alarmSettings.assetAudioPath,
        alarmSettings.loopAudio,
        alarmSettings.vibrate,
        alarmSettings.fadeDuration,
        alarmSettings.notificationTitle,
        alarmSettings.notificationBody,
        alarmSettings.enableNotificationOnKill,
      );
    }
    return false;
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

  /// Returns alarm by given id. Returns null if not found.
  static AlarmSettings? getAlarm(int id) {
    List<AlarmSettings> alarms = AlarmStorage.getSavedAlarms();

    for (final alarm in alarms) {
      if (alarm.id == id) return alarm;
    }
    alarmPrint('Alarm with id $id not found.');
    return null;
  }

  /// Returns all the alarms.
  static List<AlarmSettings> getAlarms() => AlarmStorage.getSavedAlarms();
}
