// ignore_for_file: avoid_print

import 'package:alarm/notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'alarm_platform_interface.dart';

/// An implementation of [AlarmPlatform] that uses method channels.
class MethodChannelAlarm extends AlarmPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.gdelataillade/alarm');

  @override
  Future<bool> setAlarm(
    DateTime dateTime,
    String assetAudio,
    String? notifTitle,
    String? notifBody,
  ) async {
    final delay = dateTime.difference(DateTime.now());

    final res = await methodChannel.invokeMethod<bool?>(
          'setAlarm',
          {
            "assetAudio": assetAudio,
            "delayInSeconds": delay.inSeconds.abs().toDouble(),
          },
        ) ??
        false;

    if (res && notifTitle != null && notifBody != null) {
      Notification.instance.scheduleIOSAlarmNotif(
        dateTime: dateTime,
        title: notifTitle,
        body: notifBody,
      );
    }

    print("[Alarm] setAlarm returned: $res");
    return res;
  }

  @override
  Future<bool> stopAlarm() async {
    final res = await methodChannel.invokeMethod<bool>('stopAlarm');
    print("[Alarm] stopAlarm returned: $res");
    return res ?? false;
  }
}
