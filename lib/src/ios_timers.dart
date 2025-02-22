import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:logging/logging.dart';

/// Fallback logic for iOS alarm triggering.
class IOSTimers {
  static final _log = Logger('IOSTimers');

  /// Map of alarm timers.
  static final Map<int, Timer?> _timers = {};

  /// Map of foreground/background subscriptions.
  static final Map<int, StreamSubscription<FGBGType>?> _fgbgSubscriptions = {};

  /// Listens for alarm trigger.
  static void setAlarm(AlarmSettings settings) {
    final id = settings.id;

    final timer = _timers[id];
    if (timer != null && timer.isActive) {
      _disposeAlarm(id);
    }

    _timers[id] = _periodicTimer(
      () => unawaited(_alarmRang(settings)),
      settings.dateTime,
      id,
    );

    _listenAppStateChange(
      id: id,
      onBackground: () => _disposeTimer(id),
      onForeground: () async {
        if (_fgbgSubscriptions[id] == null) return;

        final alarmIsRinging = await IOSAlarm.isRinging(id);

        if (alarmIsRinging) {
          _disposeAlarm(id);
          unawaited(_alarmRang(settings));
        } else {
          final timer = _timers[id];
          if (timer != null && timer.isActive) {
            timer.cancel();
          }
          _timers[id] = _periodicTimer(
            () => unawaited(_alarmRang(settings)),
            settings.dateTime,
            id,
          );
        }
      },
    );
  }

  /// Stops listening for alarm trigger.
  static void stopAlarm(int id) {
    _disposeAlarm(id);
  }

  /// Stops listening for all alarm triggers.
  static void stopAll() {
    for (final id in _timers.keys) {
      stopAlarm(id);
    }
  }

  /// Listens when app goes foreground so we can check if alarm is ringing.
  /// When app goes background, periodical timer will be disposed.
  static void _listenAppStateChange({
    required int id,
    required void Function() onForeground,
    required void Function() onBackground,
  }) {
    _fgbgSubscriptions[id] = FGBGEvents.instance.stream.listen((event) {
      if (event == FGBGType.foreground) onForeground();
      if (event == FGBGType.background) onBackground();
    });
  }

  /// Checks periodically if alarm is ringing, as long as app is in foreground.
  static Timer _periodicTimer(void Function()? onRing, DateTime dt, int id) {
    return Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (DateTime.now().isBefore(dt)) return;
      _disposeAlarm(id);
      onRing?.call();
    });
  }

  /// Disposes alarm timer.
  static void _disposeTimer(int id) {
    _timers[id]?.cancel();
    _timers.removeWhere((key, value) => key == id);
  }

  /// Disposes alarm timer and FGBG subscription.
  static void _disposeAlarm(int id) {
    _disposeTimer(id);
    _fgbgSubscriptions[id]?.cancel();
    _fgbgSubscriptions.removeWhere((key, value) => key == id);
  }

  static Future<void> _alarmRang(AlarmSettings settings) async {
    if (Alarm.ringing.value.contains(settings)) {
      _log.info('Alarm timer triggered but alarm is already marked as ringing. '
          'Info: ${settings.toJson()}');
      return;
    }

    // Give the native platform sometime to notify Flutter.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (Alarm.ringing.value.contains(settings)) {
      _log.info('Alarm timer triggered but native marked the alarm as ringing '
          'shortly after. Info: ${settings.toJson()}');
      return;
    }

    _log.warning('Alarm had to be triggered manually via timer. '
        'Info: ${settings.toJson()}');
    Alarm.alarmRang(settings);
  }
}
