import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

/// Uses method channel to interact with the native platform.
class IOSAlarm {
  /// Method channel for the alarm.
  static const methodChannel = MethodChannel('com.gdelataillade/alarm');

  /// Map of alarm timers.
  static Map<int, Timer?> timers = {};

  /// Map of foreground/background subscriptions.
  static Map<int, StreamSubscription<FGBGType>?> fgbgSubscriptions = {};

  /// Initializes the method call handler.
  static void init() => methodChannel.setMethodCallHandler(handleMethodCall);

  /// Handles incoming method calls from the native platform.
  static Future<void> handleMethodCall(MethodCall call) async {
    debugPrint('handleMethodCall: ${call.method}');
    // switch (call.method) {
    //   case 'alarmStoppedFromNotification':
    //     print('call.arguments: ${call.arguments}');
    //     final arguments = call.arguments as Map<dynamic, dynamic>;
    //     final id = arguments['id'] as int;
    //   // await handleAlarmStoppedFromNotification(id);
    //   case 'alarmSnoozedFromNotification':
    //     print('call.arguments: ${call.arguments}');
    //     final arguments = call.arguments as Map<dynamic, dynamic>;
    //     final id = arguments['id'] as int;
    //     final snoozeDurationInSeconds =
    //         arguments['snoozeDurationInSeconds'] as int;
    //   // await handleAlarmSnoozedFromNotification(id, snoozeDurationInSeconds);
    //   default:
    //     throw MissingPluginException('not implemented');
    // }
  }

  /// Handles the alarm stopped from notification event.
  static Future<void> handleAlarmStoppedFromNotification(int id) async {
    // AlarmStorage.unsaveAlarm(id);
    // disposeAlarm(id);
    await Alarm.stop(id);
    alarmPrint('Alarm with id $id was stopped from notification');
  }

  /// Handles the alarm snoozed from notification event.
  static Future<void> handleAlarmSnoozedFromNotification(
    int id,
    int snoozeDurationInSeconds,
  ) async {
    final alarm = await Alarm.getAlarm(id);
    if (alarm == null) {
      alarmPrint('Alarm with id $id was not found. Snooze failed.');
      return;
    }

    await Alarm.stop(id);

    final newAlarm = alarm.copyWith(
      dateTime: DateTime.now().add(Duration(seconds: snoozeDurationInSeconds)),
    );
    await Alarm.set(alarmSettings: newAlarm);

    alarmPrint('Alarm with id $id was snoozed for ${snoozeDurationInSeconds}s');
  }

  /// Calls the native function `setAlarm` and listens to alarm ring state.
  ///
  /// Also set periodic timer and listens for app state changes to trigger
  /// the alarm ring callback at the right time.
  static Future<bool> setAlarm(
    AlarmSettings settings,
    void Function()? onRing,
  ) async {
    final id = settings.id;
    try {
      final res = await methodChannel.invokeMethod<bool?>(
            'setAlarm',
            settings.toJson(),
          ) ??
          false;

      alarmPrint(
        '''Alarm with id $id scheduled ${res ? 'successfully' : 'failed'} at ${settings.dateTime}''',
      );

      if (!res) return false;
    } catch (e) {
      await Alarm.stop(id);
      throw AlarmException(e.toString());
    }

    if (timers[id] != null && timers[id]!.isActive) timers[id]!.cancel();
    timers[id] = periodicTimer(onRing, settings.dateTime, id);

    listenAppStateChange(
      id: id,
      onBackground: () => disposeTimer(id),
      onForeground: () async {
        final alarms = await Alarm.getSavedAlarms();
        print(alarms);

        if (fgbgSubscriptions[id] == null) return;

        final isRinging = await checkIfRinging(id);

        if (isRinging) {
          disposeAlarm(id);
          onRing?.call();
        } else {
          if (timers[id] != null && timers[id]!.isActive) timers[id]!.cancel();
          timers[id] = periodicTimer(onRing, settings.dateTime, id);
        }
      },
    );

    return true;
  }

  /// Disposes timer and FGBG subscription
  /// and calls the native `stopAlarm` function.
  static Future<bool> stopAlarm(int id) async {
    disposeAlarm(id);

    final res = await methodChannel.invokeMethod<bool?>(
          'stopAlarm',
          {'id': id},
        ) ??
        false;

    if (res) alarmPrint('Alarm with id $id stopped');

    return res;
  }

  /// Returns the list of saved alarms stored locally.
  static Future<List<AlarmSettings>> getSavedAlarms() async {
    final res = await methodChannel
            .invokeMethod<List<AlarmSettings>?>('getSavedAlarms') ??
        [];

    return res
        .map((e) => AlarmSettings.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Checks whether alarm is ringing by getting the native audio player's
  /// current time at two different moments. If the two values are different,
  /// it means the alarm is ringing and then returns `true`.
  static Future<bool> checkIfRinging(int id) async {
    final pos1 = await methodChannel
            .invokeMethod<double?>('audioCurrentTime', {'id': id}) ??
        0.0;
    await Future.delayed(const Duration(milliseconds: 100), () {});
    final pos2 = await methodChannel
            .invokeMethod<double?>('audioCurrentTime', {'id': id}) ??
        0.0;

    return pos2 > pos1;
  }

  /// Listens when app goes foreground so we can check if alarm is ringing.
  /// When app goes background, periodical timer will be disposed.
  static void listenAppStateChange({
    required int id,
    required void Function() onForeground,
    required void Function() onBackground,
  }) {
    fgbgSubscriptions[id] = FGBGEvents.stream.listen((event) {
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
  static Future<void> setNotificationOnAppKill(String title, String body) =>
      methodChannel.invokeMethod<void>(
        'setNotificationOnAppKillContent',
        {'title': title, 'body': body},
      );

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
