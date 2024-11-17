import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/utils/alarm_exception.dart';

/// Uses method channel to interact with the native platform.
class AndroidAlarm {
  static final AlarmApi _api = AlarmApi();

  /// Whether there are other alarms set.
  static bool get hasOtherAlarms => Alarm.getAlarms().length > 1;

  /// Schedules a native alarm with given [settings] with its notification.
  static Future<bool> set(AlarmSettings settings) async {
    try {
      await _api.setAlarm(alarmSettings: settings.toWire());
    } catch (e) {
      throw AlarmException('AndroidAlarm.setAlarm error: $e');
    }

    alarmPrint(
      '''Alarm with id ${settings.id} scheduled at ${settings.dateTime}''',
    );

    return true;
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    try {
      await _api.stopAlarm(alarmId: id);
      if (!hasOtherAlarms) await disableWarningNotificationOnKill();
      return true;
    } catch (e) {
      alarmPrint('Failed to stop alarm: $e');
      return false;
    }
  }

  /// Checks whether an alarm or any alarm (if id is null) is ringing.
  static Future<bool> isRinging([int? id]) async {
    try {
      final res = await _api.isRinging(alarmId: id);
      return res;
    } catch (e) {
      alarmPrint('Failed to check if alarm is ringing: $e');
      return false;
    }
  }

  /// Sets the native notification on app kill title and body.
  static Future<void> setWarningNotificationOnKill(String title, String body) =>
      _api.setWarningNotificationOnKill(
        title: title,
        body: body,
      );

  /// Disable the notification on kill service.
  static Future<void> disableWarningNotificationOnKill() async {
    try {
      await _api.disableWarningNotificationOnKill();
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
