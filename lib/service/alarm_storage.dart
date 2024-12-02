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

  /// Shared preferences instance.
  static late SharedPreferences _prefs;

  /// Stream subscription to listen to foreground/background events.
  static late StreamSubscription<FGBGType> _fgbgSubscription;

  static bool _initialized = false;

  /// Initializes shared preferences instance.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    /// Reloads the shared preferences instance in the case modifications
    /// were made in the native code, after a notification action.
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen((event) => _prefs.reload());

    _initialized = true;
  }

  static Future<void> _waitUntilInitialized() async {
    while (!_initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Saves alarm info in local storage so we can restore it later
  /// in the case app is terminated.
  static Future<void> saveAlarm(AlarmSettings alarmSettings) async {
    await _waitUntilInitialized();
    await _prefs.setString(
      '$prefix${alarmSettings.id}',
      json.encode(alarmSettings.toJson()),
    );
  }

  /// Removes alarm from local storage.
  static Future<void> unsaveAlarm(int id) async {
    await _waitUntilInitialized();
    await _prefs.remove('$prefix$id');
  }

  /// Whether at least one alarm is set.
  static Future<bool> hasAlarm() async {
    await _waitUntilInitialized();

    final keys = _prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) return true;
    }

    return false;
  }

  /// Returns all alarms info from local storage in the case app is terminated
  /// and we need to restore previously scheduled alarms.
  static Future<List<AlarmSettings>> getSavedAlarms() async {
    await _waitUntilInitialized();

    final alarms = <AlarmSettings>[];
    final keys = _prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) {
        final res = _prefs.getString(key);
        alarms.add(
          AlarmSettings.fromJson(json.decode(res!) as Map<String, dynamic>),
        );
      }
    }

    return alarms;
  }

  /// Dispose the fgbg subscription to avoid memory leaks.
  static void dispose() {
    _fgbgSubscription.cancel();
  }
}
