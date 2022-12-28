// ignore_for_file: avoid_print

import 'dart:async';

import 'package:alarm/notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

import 'alarm_platform_interface.dart';

/// An implementation of [AlarmPlatform] that uses method channels.
class MethodChannelAlarm extends AlarmPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.gdelataillade/alarm');

  Timer? timer;

  @override
  Future<bool> setAlarm(
    DateTime dateTime,
    void Function()? onRing,
    String assetAudio,
    bool loopAudio,
    String? notifTitle,
    String? notifBody,
  ) async {
    final delay = dateTime.difference(DateTime.now());

    if (notifTitle != null && notifBody != null) {
      Notification.instance.scheduleIOSAlarmNotif(
        dateTime: dateTime,
        title: notifTitle,
        body: notifBody,
      );
    }

    final res = await methodChannel.invokeMethod<bool?>(
      'setAlarm',
      {
        "assetAudio": assetAudio,
        "delayInSeconds": delay.inSeconds.abs().toDouble(),
        "loopAudio": loopAudio,
      },
    );

    print("[Alarm] setAlarm returned: $res");

    if (res == null || res == false) return false;

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

  @override
  Future<bool> stopAlarm() async {
    final res = await methodChannel.invokeMethod<bool?>('stopAlarm');
    print("[Alarm] stopAlarm returned: $res");
    return res ?? false;
  }

  @override
  Future<bool> checkIfRinging() async {
    final pos1 =
        await methodChannel.invokeMethod<double?>('audioCurrentTime') ?? 0.0;
    await Future.delayed(const Duration(milliseconds: 100));
    final pos2 =
        await methodChannel.invokeMethod<double?>('audioCurrentTime') ?? 0.0;
    print("[Alarm] player audioCurrentTime $pos1 and $pos2");
    return pos2 > pos1;
  }

  static void listenAppStateChange(
      {required void Function() onForeground}) async {
    FGBGEvents.stream.listen((event) {
      print("[Alarm] onAppStateChange $event");
      if (event == FGBGType.foreground) onForeground();
    });
  }

  void periodicTimer(void Function()? onRing, DateTime dt) async {
    timer?.cancel();

    if (DateTime.now().isAfter(dt)) {
      onRing?.call();
      return;
    }

    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (DateTime.now().isAfter(dt)) {
        debugPrint("[Alarm] timer periodic over");
        onRing?.call();
        timer?.cancel();
      }
    });
  }
}
