import 'package:alarm/alarm.dart';
import 'package:background_fetch/background_fetch.dart';

class AlarmBGFetch {
  static List<DateTime> fetchs = [];

  static Future<void> init() async {
    await configure();
  }

  static Future<void> configure() async {
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
    fetchs.add(DateTime.now());
    await Alarm.checkAlarm();
    BackgroundFetch.finish(taskId);
  }
}
