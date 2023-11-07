import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmStorage {
  static const prefix = '__alarm_id__';
  static const notificationOnAppKill = 'notificationOnAppKill';
  static const notificationOnAppKillTitle = 'notificationOnAppKillTitle';
  static const notificationOnAppKillBody = 'notificationOnAppKillBody';

  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  /// Saves alarm info in local storage so we can restore it later
  /// in the case app is terminated.
  static Future<void> saveAlarm(AlarmSettings alarmSettings) => prefs.setString(
        '$prefix${alarmSettings.id}',
        json.encode(alarmSettings.toJson()),
      );

  /// Removes alarm from local storage.
  static Future<void> unsaveAlarm(int id) => prefs.remove("$prefix$id");

  /// Whether at least one alarm is set.
  static bool hasAlarm() {
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) return true;
    }

    return false;
  }

  /// Returns all alarms info from local storage in the case app is terminated
  /// and we need to restore previously scheduled alarms.
  static List<AlarmSettings> getSavedAlarms() {
    final alarms = <AlarmSettings>[];
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) {
        final res = prefs.getString(key);
        alarms.add(AlarmSettings.fromJson(json.decode(res!)));
      }
    }

    return alarms;
  }

  /// Saves on app kill notification custom [title] and [body].
  static Future<void> setNotificationContentOnAppKill(
    String title,
    String body,
  ) =>
      Future.wait([
        prefs.setString(notificationOnAppKillTitle, title),
        prefs.setString(notificationOnAppKillBody, body),
      ]);

  /// Returns notification on app kill [title].
  static String getNotificationOnAppKillTitle() =>
      prefs.getString(notificationOnAppKillTitle) ?? 'Your alarms may not ring';

  /// Returns notification on app kill [body].
  static String getNotificationOnAppKillBody() =>
      prefs.getString(notificationOnAppKillBody) ??
      'You killed the app. Please reopen so your alarms can be rescheduled.';
}
