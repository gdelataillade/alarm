import 'dart:convert';

import 'package:alarm/alarm_model.dart';
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

  static Future<void> setBool(String key, bool value) =>
      prefs.setBool(key, value);

  static bool? getBool(String key) => prefs.getBool(key);

  static Future<void> setCurrentAlarm(
    AlarmModel currentAlarm,
  ) async {
    await prefs.setString("currentAlarm", json.encode(currentAlarm.toString()));
  }

  static AlarmModel? getCurrentAlarm() {
    final res = prefs.getString("currentAlarm");
    if (res == null) return null;
    AlarmModel.fromJson(json.decode(res!));
  }

  static Future<void> setNotificationContentOnRing(
    String title,
    String body,
  ) async {
    await prefs.setString(notificationOnRingTitle, title);
    await prefs.setString(notificationOnRingBody, body);
  }

  static String getNotificationOnRingTitle() =>
      prefs.getString(notificationOnRingTitle) ?? 'Your alarm is ringing...';

  static String getNotificationOnRingBody() =>
      prefs.getString(notificationOnRingBody) ?? 'Tap here to open the app';

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
