import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/src/platform_timers.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:alarm/utils/alarm_handler.dart';
import 'package:logging/logging.dart';

/// Abstract base class for platform-specific alarm interactions.
/// Contains common logic shared between iOS and Android.
abstract class BaseAlarm {
  /// Creates a [BaseAlarm] instance with the provided logger.
  BaseAlarm(this._log);

  /// The shared API instance for alarm operations.
  static final AlarmApi api = AlarmApi();

  final Logger _log;

  /// Schedules a native alarm with given [settings] with its notification.
  ///
  /// Also sets periodic timer and listens for app state changes to trigger
  /// the alarm ring callback at the right time.
  Future<bool> setAlarm(AlarmSettings settings) async {
    final id = settings.id;
    try {
      await api
          .setAlarm(alarmSettings: settings.toWire())
          .catchError(AlarmExceptionHandlers.catchError<void>);

      _log.info(
        'Alarm with id $id scheduled successfully at ${settings.dateTime}',
      );
    } on AlarmException catch (_) {
      await Alarm.stop(id);
      rethrow;
    }

    PlatformTimers.setAlarm(settings);

    return true;
  }

  /// Stops the alarm with the given [id].
  Future<bool> stopAlarm(int id) async {
    PlatformTimers.stopAlarm(id);

    try {
      await api
          .stopAlarm(alarmId: id)
          .catchError(AlarmExceptionHandlers.catchError<void>);

      _log.info('Alarm with id $id stopped.');

      return true;
    } on AlarmException catch (e) {
      _log.severe('Failed to stop alarm $id. $e');
      return false;
    }
  }

  /// Stops all alarms.
  Future<void> stopAll() async {
    PlatformTimers.stopAll();
    return api.stopAll().catchError(AlarmExceptionHandlers.catchError<void>);
  }

  /// Checks whether an alarm or any alarm (if id is null) is ringing.
  Future<bool> isRinging([int? id]) async {
    try {
      final res = await api
          .isRinging(alarmId: id)
          .catchError(AlarmExceptionHandlers.catchError<bool>);
      return res;
    } on AlarmException catch (e) {
      _log.severe('Failed to check if alarm is ringing: $e');
      return false;
    }
  }

  /// Sets the native notification on app kill title and body.
  Future<void> setWarningNotificationOnKill(String title, String body) => api
      .setWarningNotificationOnKill(
        title: title,
        body: body,
      )
      .catchError(AlarmExceptionHandlers.catchError<void>);
}
