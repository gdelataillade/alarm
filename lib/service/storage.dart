import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const prefix = '__alarm_id__';
const notificationOnAppKill = 'notificationOnAppKill';
const notificationOnAppKillTitle = 'notificationOnAppKillTitle';
const notificationOnAppKillBody = 'notificationOnAppKillBody';

class AlarmStorage {
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

  /// Remove alarm from local storage.
  static Future<void> unsaveAlarm(int id) => prefs.remove("$prefix$id");

  /// Wether an alarm is set or not.
  static bool hasAlarm() {
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Gets alarm info from local storage in the case app is terminated and
  /// we need to restore the alarm.
  static AlarmSettings? getSavedAlarm(int id) {
    final res = prefs.getString("$prefix$id");
    if (res == null) return null;
    return AlarmSettings.fromJson(json.decode(res));
  }

  /// Saves on app kill notification custom title and body.
  static Future<void> setNotificationContentOnAppKill(
    String title,
    String body,
  ) =>
      Future.wait([
        prefs.setString(notificationOnAppKillTitle, title),
        prefs.setString(notificationOnAppKillBody, body),
      ]);

  /// Returns notification on app kill title.
  static String getNotificationOnAppKillTitle() =>
      prefs.getString(notificationOnAppKillTitle) ?? 'Your alarm may not ring';

  /// Returns notification on app kill body.
  static String getNotificationOnAppKillBody() =>
      prefs.getString(notificationOnAppKillBody) ??
      'You killed the app. Please reopen so your alarm can be rescheduled.';
}
