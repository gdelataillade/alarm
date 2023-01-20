import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const notificationOnRingTitle = 'notificationOnRingTitle';
const notificationOnRingBody = 'notificationOnRingBody';
const notificationOnAppKillTitle = 'notificationOnAppKillTitle';
const notificationOnAppKillBody = 'notificationOnAppKillBody';

class Storage {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setCurrentAlarm(
    AlarmSettings currentAlarm,
  ) async {
    await prefs.setString("currentAlarm", json.encode(currentAlarm.toJson()));
  }

  static AlarmSettings? getCurrentAlarm() {
    final res = prefs.getString("currentAlarm");
    if (res == null) return null;
    return AlarmSettings.fromJson(json.decode(res));
  }

  static Future<void> setNotificationContentOnAppKill(
    String title,
    String body,
  ) async {
    await prefs.setString(notificationOnAppKillTitle, title);
    await prefs.setString(notificationOnAppKillBody, body);
  }

  static String getNotificationOnAppKillTitle() =>
      prefs.getString(notificationOnAppKillTitle) ?? 'Your alarm may not ring';

  static String getNotificationOnAppKillBody() =>
      prefs.getString(notificationOnAppKillBody) ??
      'You killed the app. Please reopen so your alarm can ring.';
}
