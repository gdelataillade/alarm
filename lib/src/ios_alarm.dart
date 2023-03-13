// ignore_for_file: avoid_print

import 'dart:async';

import 'package:alarm/service/notification.dart';
import 'package:alarm/service/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

/// Uses method channel to interact with the native platform.
class IOSAlarm {
  static MethodChannel methodChannel =
      const MethodChannel('com.gdelataillade/alarm');

  static Map<int, Timer?> timers = {};
  static Map<int, StreamSubscription<FGBGType>?> fgbgSubscriptions = {};

  /// Schedules an iOS notification for the moment the alarm starts ringing.
  /// Then calls the native function `setAlarm` and listens to alarm ring state.
  static Future<bool> setAlarm(
    int id,
    DateTime dateTime,
    void Function()? onRing,
    String assetAudio,
    bool loopAudio,
    double fadeDuration,
    String? notificationTitle,
    String? notificationBody,
    bool enableNotificationOnKill,
  ) async {
    final delay = dateTime.difference(DateTime.now());

    if (notificationTitle != null &&
        notificationTitle.isNotEmpty &&
        notificationBody != null &&
        notificationBody.isNotEmpty) {
      AlarmNotification.instance.scheduleAlarmNotif(
        id: id,
        dateTime: dateTime,
        title: notificationTitle,
        body: notificationBody,
      );
    }

    // TODO: Add explicit error when wrong asset path is given (instead of crash)
    final res = await methodChannel.invokeMethod<bool?>(
          'setAlarm',
          {
            'id': id,
            'assetAudio': assetAudio,
            'delayInSeconds': delay.inSeconds.abs().toDouble(),
            'loopAudio': loopAudio,
            'fadeDuration': fadeDuration >= 0 ? fadeDuration : 0,
            'notifOnKillEnabled': enableNotificationOnKill,
            'notifTitleOnAppKill': AlarmStorage.getNotificationOnAppKillTitle(),
            'notifDescriptionOnAppKill':
                AlarmStorage.getNotificationOnAppKillBody(),
          },
        ) ??
        false;

    print('[Alarm] alarm with id $id set ${res ? 'successfully' : 'failed'}');

    if (res == false) return false;

    timers[id] = periodicTimer(onRing, dateTime, id);

    listenAppStateChange(
      id: id,
      onBackground: () => disposeTimer(id),
      onForeground: () async {
        final isRinging = await checkIfRinging(id);

        if (isRinging) {
          disposeAlarm(id);
          onRing?.call();
        } else {
          timers[id] = periodicTimer(onRing, dateTime, id);
        }
      },
    );
    return true;
  }

  /// Disposes timer and FGBG subscription
  /// and calls the native stopAlarm function.
  static Future<bool> stopAlarm(int id) async {
    disposeAlarm(id);

    try {
      final res = await methodChannel.invokeMethod<bool?>(
            'stopAlarm',
            {'id': id},
          ) ??
          false;

      print('[Alarm] alarm with id $id stopped with success');
      return res;
    } catch (e) {
      print('[Alarm] alarm with id $id stop error: $e');
      return false;
    }
  }

  /// Checks whether alarm is ringing by getting the native audio player's
  /// current time at two different moments. If the two values are different,
  /// it means the alarm is ringing.
  static Future<bool> checkIfRinging(int id) async {
    final pos1 = await methodChannel
            .invokeMethod<double?>('audioCurrentTime', {'id': id}) ??
        0.0;
    await Future.delayed(const Duration(milliseconds: 100));
    final pos2 = await methodChannel
            .invokeMethod<double?>('audioCurrentTime', {'id': id}) ??
        0.0;
    final isRinging = pos2 > pos1;
    return isRinging;
  }

  /// Listens when app goes foreground so we can check if alarm is ringing.
  /// When app goes background, periodical timer will be disposed.
  static void listenAppStateChange({
    required int id,
    required void Function() onForeground,
    required void Function() onBackground,
  }) async {
    fgbgSubscriptions[id] = FGBGEvents.stream.listen((event) {
      if (event == FGBGType.foreground) onForeground();
      if (event == FGBGType.background) onBackground();
    });
  }

  /// Checks periodically if alarm is ringing, as long as app is in foreground.
  static Timer periodicTimer(void Function()? onRing, DateTime dt, int id) {
    return Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (DateTime.now().isAfter(dt)) {
        disposeAlarm(id);
        onRing?.call();
      }
    });
  }

  static void disposeTimer(int id) {
    timers[id]?.cancel();
    timers.removeWhere((key, value) => key == id);
  }

  static void disposeAlarm(int id) {
    disposeTimer(id);
    fgbgSubscriptions[id]?.cancel();
    fgbgSubscriptions.removeWhere((key, value) => key == id);
  }
}
