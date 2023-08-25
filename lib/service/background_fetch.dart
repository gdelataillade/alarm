import 'package:alarm/alarm.dart';
import 'package:background_fetch/background_fetch.dart';

/// The purpose of this class is to trigger a background fetch event
/// every 15 minutes to reschedule all the alarms to make sure the alarms
/// are still active.
class AlarmBackgroundFetch {
  static List<DateTime> fetches = [];

  static Future<void> init() async {
    final config = BackgroundFetchConfig(
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

    final res = await BackgroundFetch.configure(config, callback);

    if (res == BackgroundFetch.STATUS_AVAILABLE) {
      alarmPrint("Background fetch is available. Minimum interval: 15 minutes");
    }
  }

  static Future<void> callback(String taskId) async {
    alarmPrint("Background fetch event received. TaskId: $taskId");
    fetches.add(DateTime.now());
    await Alarm.checkAlarm();
    BackgroundFetch.finish(taskId);
  }
}
