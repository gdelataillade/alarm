import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmStorage {
  static const prefix = '__alarm_id__';
  static const notificationOnAppKill = 'notificationOnAppKill';
  static const notificationOnAppKillTitle = 'notificationOnAppKillTitle';
  static const notificationOnAppKillBody = 'notificationOnAppKillBody';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Saves alarm info in local storage so we can restore it later
  /// in the case app is terminated.
  static Future<void> saveAlarm(AlarmSettings alarmSettings) async {
    alarmPrint('+ Save alarm: $prefix${alarmSettings.id}');
    (await prefs).setString(
      '$prefix${alarmSettings.id}',
      json.encode(alarmSettings.toJson()),
    );
  }

  /// Removes alarm from local storage.
  static Future<void> unsaveAlarm(int id) async {
    alarmPrint('- Unsave alarm: $prefix$id');
    (await prefs).remove("$prefix$id");
  }

  /// Whether at least one alarm is set.
  static Future<bool> hasAlarm() async {
    final keys = (await prefs).getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) return true;
    }

    return false;
  }

  /// Returns all alarms info from local storage in the case app is terminated
  /// and we need to restore previously scheduled alarms.
  static Future<List<AlarmSettings>> getSavedAlarms() async {
    final alarms = <AlarmSettings>[];
    final keys = (await prefs).getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) {
        final res = (await prefs).getString(key);
        if (res == null) {
          continue;
        }

        alarms.add(AlarmSettings.fromJson(json.decode(res)));
      }
    }

    return alarms;
  }

  /// Saves on app kill notification custom [title] and [body].
  static Future<void> setNotificationContentOnAppKill(
    String title,
    String body,
  ) async =>
      Future.wait([
        (await prefs).setString(notificationOnAppKillTitle, title),
        (await prefs).setString(notificationOnAppKillBody, body),
      ]);

  /// Returns notification on app kill [title].
  static Future<String> getNotificationOnAppKillTitle() async =>
      (await prefs).getString(notificationOnAppKillTitle) ??
      'Your alarms may not ring';

  /// Returns notification on app kill [body].
  static Future<String> getNotificationOnAppKillBody() async =>
      (await prefs).getString(notificationOnAppKillBody) ??
      'You killed the app. Please reopen so your alarms can be rescheduled.';
}
