import 'dart:async';

import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/service/alarm_storage.dart';
import 'package:alarm/src/alarm_trigger_api_impl.dart';
import 'package:alarm/src/android_alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:alarm/utils/extensions.dart';
import 'package:flutter/foundation.dart';

export 'package:alarm/model/alarm_settings.dart';
export 'package:alarm/model/notification_settings.dart';

/// Custom print function designed for Alarm plugin.
DebugPrintCallback alarmPrint = debugPrintThrottled;

/// Class that handles the alarm.
class Alarm {
  /// Whether it's iOS device.
  static bool get iOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether it's Android device.
  static bool get android => defaultTargetPlatform == TargetPlatform.android;

  /// Stream of the alarm updates.
  static final updateStream = StreamController<int>();

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
      if (showDebugLogs) debugPrint('[Alarm] $message');
    };

    AlarmTriggerApiImpl.ensureInitialized();

    await AlarmStorage.init();

    await checkAlarm();
  }

  /// Checks if some alarms were set on previous session.
  /// If it's the case then reschedules them.
  static Future<void> checkAlarm() async {
    final alarms = await getAlarms();

    if (iOS) await stopAll();

    for (final alarm in alarms) {
      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        await set(alarmSettings: alarm);
      } else {
        final isRinging = await Alarm.isRinging(alarm.id);
        isRinging ? ringStream.add(alarm) : await stop(alarm.id);
      }
    }
  }

  /// Schedules an alarm with given [alarmSettings] with its notification.
  ///
  /// If you set an alarm for the same dateTime as an existing one,
  /// the new alarm will replace the existing one.
  static Future<bool> set({required AlarmSettings alarmSettings}) async {
    alarmSettingsValidation(alarmSettings);

    final alarms = await getAlarms();

    for (final alarm in alarms) {
      if (alarm.id == alarmSettings.id ||
          alarm.dateTime.isSameSecond(alarmSettings.dateTime)) {
        await Alarm.stop(alarm.id);
      }
    }

    await AlarmStorage.saveAlarm(alarmSettings);

    final success = iOS
        ? await IOSAlarm.setAlarm(alarmSettings)
        : await AndroidAlarm.set(alarmSettings);

    if (success) {
      updateStream.add(alarmSettings.id);
    }

    return success;
  }

  /// Validates [alarmSettings] fields.
  static void alarmSettingsValidation(AlarmSettings alarmSettings) {
    if (alarmSettings.id == 0 || alarmSettings.id == -1) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message: 'Alarm id cannot be 0 or -1. Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.id > 2147483647) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message:
            'Alarm id cannot be set larger than Int max value (2147483647). '
            'Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.id < -2147483648) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message:
            'Alarm id cannot be set smaller than Int min value (-2147483648). '
            'Provided: ${alarmSettings.id}',
      );
    }
  }

  /// When the app is killed, all the processes are terminated
  /// so the alarm may never ring. By default, to warn the user, a notification
  /// is shown at the moment he kills the app.
  /// This methods allows you to customize this notification content.
  ///
  /// [title] default value is `Your alarm may not ring`
  ///
  /// [body] default value is `You killed the app.
  /// Please reopen so your alarm can ring.`
  static Future<void> setWarningNotificationOnKill(
    String title,
    String body,
  ) async {
    if (iOS) await IOSAlarm.setWarningNotificationOnKill(title, body);
    if (android) await AndroidAlarm.setWarningNotificationOnKill(title, body);
  }

  /// Stops alarm.
  static Future<bool> stop(int id) async {
    await AlarmStorage.unsaveAlarm(id);
    updateStream.add(id);

    return iOS ? await IOSAlarm.stopAlarm(id) : await AndroidAlarm.stop(id);
  }

  /// Stops all the alarms.
  static Future<void> stopAll() async {
    final alarms = await getAlarms();

    iOS ? await IOSAlarm.stopAll() : await AndroidAlarm.stopAll();

    await AlarmStorage.unsaveAll();

    for (final alarm in alarms) {
      updateStream.add(alarm.id);
    }
  }

  /// Whether the alarm is ringing.
  ///
  /// If no `id` is provided, it checks if any alarm is ringing.
  /// If an `id` is provided, it checks if the specific alarm with that `id`
  /// is ringing.
  static Future<bool> isRinging([int? id]) async =>
      iOS ? await IOSAlarm.isRinging(id) : await AndroidAlarm.isRinging(id);

  /// Whether an alarm is set.
  static Future<bool> hasAlarm() => AlarmStorage.hasAlarm();

  /// Returns alarm by given id. Returns null if not found.
  static Future<AlarmSettings?> getAlarm(int id) async {
    final alarms = await getAlarms();

    for (final alarm in alarms) {
      if (alarm.id == id) return alarm;
    }
    alarmPrint('Alarm with id $id not found.');

    return null;
  }

  /// Returns all the alarms.
  static Future<List<AlarmSettings>> getAlarms() =>
      AlarmStorage.getSavedAlarms();

  /// Reloads the shared preferences instance in the case modifications
  /// were made in the native code, after a notification action.
  static Future<void> reload(int id) async {
    // TODO(orkun1675): Remove this function and publish stream updates for
    // alarm start/stop events.
    updateStream.add(id);
  }
}
