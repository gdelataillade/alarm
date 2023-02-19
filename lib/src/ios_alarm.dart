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

  static Timer? timer;
  static StreamSubscription<FGBGType>? fgbgSubscription;

  /// Schedule an iOS notification for the moment the alarm starts ringing.
  /// Then call the native function setAlarm.
  static Future<bool> setAlarm(
    DateTime dateTime,
    void Function()? onRing,
    String assetAudio,
    bool loopAudio,
    String notificationTitle,
    String notificationBody,
  ) async {
    final delay = dateTime.difference(DateTime.now());

    if (notificationTitle.isNotEmpty && notificationBody.isNotEmpty) {
      Notification.instance.scheduleIOSAlarmNotif(
        dateTime: dateTime,
        title: notificationTitle,
        body: notificationBody,
      );
    }

    final res = await methodChannel.invokeMethod<bool?>(
          'setAlarm',
          {
            'assetAudio': assetAudio,
            'delayInSeconds': delay.inSeconds.abs().toDouble(),
            'loopAudio': loopAudio,
            'notifTitleOnAppKill': Storage.getNotificationOnAppKillTitle(),
            'notifDescriptionOnAppKill': Storage.getNotificationOnAppKillBody(),
          },
        ) ??
        false;

    print('[Alarm] alarm set ${res ? 'successfully' : 'failed'}');

    if (res == false) return false;

    periodicTimer(onRing, dateTime);

    listenAppStateChange(
      onBackground: () => timer?.cancel(),
      onForeground: () async {
        final hasAlarm = Storage.hasAlarm();
        print('[Alarm] Storage has alarm: ${hasAlarm ? 'true' : 'false'}');
        if (!hasAlarm) return;

        final isRinging = await checkIfRinging();
        if (isRinging) {
          dispose();
          onRing?.call();
        } else {
          periodicTimer(onRing, dateTime);
        }
      },
    );

    return true;
  }

  /// Calls the native stopAlarm function.
  static Future<bool> stopAlarm() async {
    final res = await methodChannel.invokeMethod<bool?>('stopAlarm') ?? false;
    print('[Alarm] alarm stopped ${res ? 'with success' : 'failed'}');
    return res;
  }

  /// Checks whether alarm is ringing by getting the native audio player's
  /// current time at two different moments. If the two values are different,
  /// it means the alarm is ringing.
  static Future<bool> checkIfRinging() async {
    final pos1 =
        await methodChannel.invokeMethod<double?>('audioCurrentTime') ?? 0.0;
    await Future.delayed(const Duration(milliseconds: 100));
    final pos2 =
        await methodChannel.invokeMethod<double?>('audioCurrentTime') ?? 0.0;
    final isRinging = pos2 > pos1;
    print('[Alarm] check if ringing: $isRinging');
    return isRinging;
  }

  /// Listens when app goes foreground so we can check if alarm is ringing.
  static void listenAppStateChange({
    required void Function() onForeground,
    required void Function() onBackground,
  }) async {
    fgbgSubscription = FGBGEvents.stream.listen((event) {
      print('[Alarm] onAppStateChange $event');
      if (event == FGBGType.foreground) onForeground();
      if (event == FGBGType.background) onBackground();
    });
  }

  /// Checks periodically if alarm is ringing, as long as app is in foreground.
  static void periodicTimer(void Function()? onRing, DateTime dt) async {
    timer?.cancel();

    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      print('[Alarm] tick');
      final hasAlarm = Storage.hasAlarm();
      if (!hasAlarm) {
        dispose();
        return;
      }

      if (DateTime.now().isAfter(dt)) {
        print('[Alarm] onRing from periodicTimer');
        print('[Alarm] now: ${DateTime.now()} vs $dt');
        print(
            '[Alarm] ${DateTime.now().millisecondsSinceEpoch} vs ${dt.millisecondsSinceEpoch}');
        dispose();
        onRing?.call();
      }
    });
  }

  static void dispose() {
    fgbgSubscription?.cancel();
    timer?.cancel();
  }
}
