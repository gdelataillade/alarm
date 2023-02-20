import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const currentAlarm = 'currentAlarm';
const notificationOnAppKill = 'notificationOnAppKill';
const notificationOnAppKillTitle = 'notificationOnAppKillTitle';
const notificationOnAppKillBody = 'notificationOnAppKillBody';

class Storage {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  /// Saves alarm info in local storage so we can restore it later
  /// in the case app is terminated.
  static Future<void> saveAlarm(AlarmSettings alarmSettings) =>
      prefs.setString(currentAlarm, json.encode(alarmSettings.toJson()));

  /// Remove alarm from local storage.
  static Future<void> unsaveAlarm() => prefs.remove(currentAlarm);

  /// Wether an alarm is set or not.
  static bool hasAlarm() => prefs.getString(currentAlarm) != null;

  /// Gets alarm info from local storage in the case app is terminated and
  /// we need to restore the alarm.
  static AlarmSettings? getSavedAlarm() {
    final res = prefs.getString(currentAlarm);
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
