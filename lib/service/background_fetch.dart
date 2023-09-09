import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:alarm/service/notification.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:background_fetch/background_fetch.dart';

/// The purpose of this class is to trigger a background fetch event
/// every 15 minutes to reschedule all the alarms to make sure the alarms
/// are still active.
class AlarmBackgroundFetch {
  static List<DateTime> fetches = [];
  static bool isActive = false;

  static BackgroundFetchConfig config = BackgroundFetchConfig(
    minimumFetchInterval: 15,
    stopOnTerminate: false,
    enableHeadless: true,
    startOnBoot: true,
    requiresBatteryNotLow: false,
    requiresCharging: false,
    requiresStorageNotLow: false,
    requiresDeviceIdle: false,
    requiredNetworkType: NetworkType.NONE,
  );

  static Future<void> set() async {
    if (isActive) return;

    final res = await BackgroundFetch.configure(config, callback);

    if (res == BackgroundFetch.STATUS_AVAILABLE) {
      isActive = true;
      alarmPrint("Background fetch activated with minimum interval: 15min.");
    } else {
      alarmPrint("Background fetch not available. Probably disabled by user.");
    }
  }

  static Future<void> stop() async {
    if (!isActive) return;
    isActive = false;

    await BackgroundFetch.stop();

    alarmPrint(
      "Background fetch stopped. ${fetches.length} fetches during this session.",
    );
  }

  static Future<void> callback(String taskId) async {
    alarmPrint("Background fetch event received. Starting background check...");

    try {
      final res = await IOSAlarm.backgroundCheck();

      final now = DateTime.now();
      AlarmNotification.instance.scheduleAlarmNotif(
        id: now.millisecond + now.second,
        dateTime: now.add(const Duration(seconds: 3)),
        title: "Alarm background check",
        body:
            "${now.hour}h${now.minute}: Silent audio player was ${res ? '' : 'not '}playing",
      );

      fetches.add(DateTime.now());

      alarmPrint("Finishing task with success...");
    } catch (e) {
      alarmPrint("Error during background check: $e");
    }

    BackgroundFetch.finish(taskId);
  }
}
