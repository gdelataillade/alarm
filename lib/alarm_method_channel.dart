// ignore_for_file: avoid_print

import 'dart:async';

import 'package:alarm/notification.dart';
import 'package:alarm/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

import 'alarm_platform_interface.dart';

/// An implementation of [AlarmPlatform] that uses method channels.
/// You can found the native functions called in the
/// SwiftAlarmPlugin.swift file in the ios folder.
class MethodChannelAlarm extends AlarmPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.gdelataillade/alarm');

  Timer? timer;

  /// Schedule an iOS notification for the moment the alarm starts ringing.
  /// Then call the native function setAlarm.
  @override
  Future<bool> setAlarm(
    DateTime dateTime,
    void Function()? onRing,
    String assetAudio,
    bool loopAudio,
    String? notificationTitle,
    String? notificationBody,
  ) async {
    final delay = dateTime.difference(DateTime.now());

    if (notificationTitle != null && notificationBody != null) {
      Notification.instance.scheduleIOSAlarmNotif(
        dateTime: dateTime,
        title: notificationTitle,
        body: notificationBody,
      );
    }

    final res = await methodChannel.invokeMethod<bool?>(
          'setAlarm',
          {
            "assetAudio": assetAudio,
            "delayInSeconds": delay.inSeconds.abs().toDouble(),
            "loopAudio": loopAudio,
            "notifTitleOnAppKill": Storage.getNotificationOnAppKillTitle(),
            "notifDescriptionOnAppKill": Storage.getNotificationOnAppKillBody(),
          },
        ) ??
        false;

    print("[Alarm] alarm set ${res ? 'successfully' : 'failed'}");

    if (res == false) return false;

    periodicTimer(onRing, dateTime);

    listenAppStateChange(
      onForeground: () async {
        final isRinging = await checkIfRinging();
        if (isRinging) {
          onRing?.call();
        } else {
          periodicTimer(onRing, dateTime);
        }
      },
    );

    return true;
  }

  /// Call the native stopAlarm function.
  @override
  Future<bool> stopAlarm() async {
    final res = await methodChannel.invokeMethod<bool?>('stopAlarm') ?? false;
    print(res
        ? "[Alarm] alarm stopped with success"
        : "[Alarm] stop failed: no alarm was set");
    return res;
  }

  /// Check if alarm is ringing by getting the native audio player's
  /// current time at two different moments. If the two values are different,
  /// it means the alarm is ringing.
  @override
  Future<bool> checkIfRinging() async {
    final pos1 =
        await methodChannel.invokeMethod<double?>('audioCurrentTime') ?? 0.0;
    await Future.delayed(const Duration(milliseconds: 100));
    final pos2 =
        await methodChannel.invokeMethod<double?>('audioCurrentTime') ?? 0.0;
    final isRinging = pos2 > pos1;
    print("[Alarm] alarm is ringing: $isRinging");
    return isRinging;
  }

  /// Listen when app goes foreground so we can check if alarm is ringing.
  static void listenAppStateChange(
      {required void Function() onForeground}) async {
    FGBGEvents.stream.listen((event) {
      print("[Alarm] onAppStateChange $event");
      if (event == FGBGType.foreground) onForeground();
    });
  }

  /// Check periodically if alarm is ringing, as long as app is in foreground.
  void periodicTimer(void Function()? onRing, DateTime dt) async {
    timer?.cancel();

    if (DateTime.now().isAfter(dt)) {
      onRing?.call();
      return;
    }

    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (DateTime.now().isAfter(dt)) {
        print("[Alarm] onRing");
        onRing?.call();
        timer?.cancel();
      }
    });
  }
}
