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

  /// Schedules an iOS notification for the moment the alarm starts ringing.
  /// Then call the native function setAlarm and listen to alarm ring state.
  static Future<bool> setAlarm(
    DateTime dateTime,
    void Function()? onRing,
    String assetAudio,
    bool loopAudio,
    String? notificationTitle,
    String? notificationBody,
    bool enableNotificationOnKill,
  ) async {
    final delay = dateTime.difference(DateTime.now());

    if (notificationTitle != null &&
        notificationTitle.isNotEmpty &&
        notificationBody != null &&
        notificationBody.isNotEmpty) {
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
            'notifOnKillEnabled': enableNotificationOnKill,
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
    return isRinging;
  }

  /// Cancels the observer that triggers the notification warning when
  /// user kills the application.
  static Future<void> stopNotificationOnKillService() async {
    try {
      await methodChannel.invokeMethod('stopNotificationOnKillService');
      print('[Alarm] NotificationOnKillService stopped with success');
    } catch (e) {
      print('[Alarm] NotificationOnKillService error: $e');
    }
  }

  /// Listens when app goes foreground so we can check if alarm is ringing.
  /// When app goes background, periodical timer will be disposed.
  static void listenAppStateChange({
    required void Function() onForeground,
    required void Function() onBackground,
  }) async {
    fgbgSubscription = FGBGEvents.stream.listen((event) {
      if (event == FGBGType.foreground) onForeground();
      if (event == FGBGType.background) onBackground();
    });
  }

  /// Checks periodically if alarm is ringing, as long as app is in foreground.
  static void periodicTimer(void Function()? onRing, DateTime dt) async {
    timer?.cancel();

    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final hasAlarm = Storage.hasAlarm();
      if (!hasAlarm) {
        dispose();
        return;
      }

      if (DateTime.now().isAfter(dt)) {
        dispose();
        onRing?.call();
      }
    });
  }

  /// Disposes FGBGType subscription and periodical timer.
  /// Also calls stopNotificationOnKillService method.
  static void dispose() {
    stopNotificationOnKillService();
    fgbgSubscription?.cancel();
    timer?.cancel();
  }
}
