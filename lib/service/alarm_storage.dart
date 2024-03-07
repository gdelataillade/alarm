import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Class that handles the local storage of the alarm info.
class AlarmStorage {
  /// Prefix to be used in local storage to identify alarm info.
  static const prefix = '__alarm_id__';

  /// Key to be used in local storage to identify
  /// notification on app kill title.
  static const notificationOnAppKill = 'notificationOnAppKill';

  /// Key to be used in local storage to identify
  /// notification on app kill body.
  static const notificationOnAppKillTitle = 'notificationOnAppKillTitle';

  /// Key to be used in local storage to identify
  /// notification on app kill body.
  static const notificationOnAppKillBody = 'notificationOnAppKillBody';

  /// Shared preferences instance.
  static late SharedPreferences prefs;

  /// Initializes shared preferences instance.
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
  static Future<void> unsaveAlarm(int id) => prefs.remove('$prefix$id');

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
        alarms.add(
          AlarmSettings.fromJson(json.decode(res!) as Map<String, dynamic>),
        );
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

  /// Returns notification on app kill [notificationOnAppKillTitle].
  static String getNotificationOnAppKillTitle() =>
      prefs.getString(notificationOnAppKillTitle) ?? 'Your alarms may not ring';

  /// Returns notification on app kill [notificationOnAppKillBody].
  static String getNotificationOnAppKillBody() =>
      prefs.getString(notificationOnAppKillBody) ??
      'You killed the app. Please reopen so your alarms can be rescheduled.';
}
