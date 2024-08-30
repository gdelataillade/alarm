import 'dart:async';
import 'dart:convert';

import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
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

  /// Stream subscription to listen to foreground/background events.
  static late StreamSubscription<FGBGType> fgbgSubscription;

  /// Shared preferences instance.
  static late SharedPreferences prefs;

  /// Initializes shared preferences instance.
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();

    /// Reloads the shared preferences instance in the case modifications
    /// were made in the native code, after a notification action.
    fgbgSubscription =
        FGBGEvents.instance.stream.listen((event) => prefs.reload());
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

  /// Dispose the fgbg subscription to avoid memory leaks.
  static void dispose() {
    fgbgSubscription.cancel();
  }
}
