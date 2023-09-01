import 'package:alarm/alarm.dart';
import 'package:background_fetch/background_fetch.dart';

/// The purpose of this class is to trigger a background fetch event
/// every 30 minutes to reschedule all the alarms to make sure the alarms
/// are still active.
class AlarmBackgroundFetch {
  static List<DateTime> fetches = [];
  static bool isActive = false;

  static BackgroundFetchConfig config = BackgroundFetchConfig(
    minimumFetchInterval: 30,
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
      alarmPrint("Background fetch activated with minimum interval: 30min.");
    } else {
      alarmPrint("Background fetch not available. Probably disabled by user.");
    }
  }

  static Future<void> stop() async {
    if (!isActive) return;

    await BackgroundFetch.stop();

    alarmPrint(
      "Background fetch stopped. ${fetches.length} fetches during this session.",
    );
  }

  static Future<void> callback(String taskId) async {
    alarmPrint("Background fetch event received. TaskId: $taskId");

    fetches.add(DateTime.now());

    await Alarm.checkAlarm();

    BackgroundFetch.finish(taskId);
  }
}
