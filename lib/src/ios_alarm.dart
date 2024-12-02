import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:alarm/utils/alarm_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

/// Uses method channel to interact with the native platform.
class IOSAlarm {
  static final AlarmApi _api = AlarmApi();

  /// Map of alarm timers.
  static Map<int, Timer?> timers = {};

  /// Map of foreground/background subscriptions.
  static Map<int, StreamSubscription<FGBGType>?> fgbgSubscriptions = {};

  /// Calls the native function `setAlarm` and listens to alarm ring state.
  ///
  /// Also set periodic timer and listens for app state changes to trigger
  /// the alarm ring callback at the right time.
  static Future<bool> setAlarm(AlarmSettings settings) async {
    final id = settings.id;
    try {
      await _api
          .setAlarm(alarmSettings: settings.toWire())
          .catchError(AlarmExceptionHandlers.catchError<void>);
      alarmPrint(
        'Alarm with id $id scheduled successfully at ${settings.dateTime}',
      );
    } on AlarmException catch (_) {
      await Alarm.stop(id);
      rethrow;
    }

    if (timers[id] != null && timers[id]!.isActive) timers[id]!.cancel();
    timers[id] = periodicTimer(
      () => Alarm.ringStream.add(settings),
      settings.dateTime,
      id,
    );

    listenAppStateChange(
      id: id,
      onBackground: () => disposeTimer(id),
      onForeground: () async {
        if (fgbgSubscriptions[id] == null) return;

        final alarmIsRinging = await isRinging(id);

        if (alarmIsRinging) {
          disposeAlarm(id);
          Alarm.ringStream.add(settings);
        } else {
          if (timers[id] != null && timers[id]!.isActive) timers[id]!.cancel();
          timers[id] = periodicTimer(
            () => Alarm.ringStream.add(settings),
            settings.dateTime,
            id,
          );
        }
      },
    );

    return true;
  }

  /// Disposes timer and FGBG subscription
  /// and calls the native `stopAlarm` function.
  static Future<bool> stopAlarm(int id) async {
    disposeAlarm(id);
    try {
      await _api
          .stopAlarm(alarmId: id)
          .catchError(AlarmExceptionHandlers.catchError<void>);
      alarmPrint('Alarm with id $id stopped');
      return true;
    } on AlarmException catch (e) {
      alarmPrint('Failed to stop alarm $id. $e');
      return false;
    }
  }

  /// Checks whether an alarm or any alarm (if id is null) is ringing.
  static Future<bool> isRinging([int? id]) async {
    try {
      final res = await _api
          .isRinging(alarmId: id)
          .catchError(AlarmExceptionHandlers.catchError<bool>);
      return res;
    } on AlarmException catch (e) {
      debugPrint('Error checking if alarm is ringing: $e');
      return false;
    }
  }

  /// Listens when app goes foreground so we can check if alarm is ringing.
  /// When app goes background, periodical timer will be disposed.
  static void listenAppStateChange({
    required int id,
    required void Function() onForeground,
    required void Function() onBackground,
  }) {
    fgbgSubscriptions[id] = FGBGEvents.instance.stream.listen((event) {
      if (event == FGBGType.foreground) onForeground();
      if (event == FGBGType.background) onBackground();
    });
  }

  /// Checks periodically if alarm is ringing, as long as app is in foreground.
  static Timer periodicTimer(void Function()? onRing, DateTime dt, int id) {
    return Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().isBefore(dt)) return;
      disposeAlarm(id);
      onRing?.call();
    });
  }

  /// Sets the native notification on app kill title and body.
  static Future<void> setWarningNotificationOnKill(String title, String body) =>
      _api
          .setWarningNotificationOnKill(title: title, body: body)
          .catchError(AlarmExceptionHandlers.catchError<void>);

  /// Disposes alarm timer.
  static void disposeTimer(int id) {
    timers[id]?.cancel();
    timers.removeWhere((key, value) => key == id);
  }

  /// Disposes alarm timer and FGBG subscription.
  static void disposeAlarm(int id) {
    disposeTimer(id);
    fgbgSubscriptions[id]?.cancel();
    fgbgSubscriptions.removeWhere((key, value) => key == id);
  }
}
