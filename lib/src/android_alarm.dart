import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/service/storage.dart';
import 'package:flutter/services.dart';

/// For Android support, [AndroidAlarmManager] is used to trigger a callback
/// when the given time is reached. The callback will run in an isolate if app
/// is in background.
class AndroidAlarm {
  static const platform = MethodChannel('com.gdelataillade.alarm/alarm');

  static bool get hasOtherAlarms => AlarmStorage.getSavedAlarms().length > 1;

  static Future<void> init() async {
    platform.setMethodCallHandler(handleMethodCall);
  }

  static Future<dynamic> handleMethodCall(MethodCall call) async {
    try {
      if (call.method == 'alarmRinging') {
        int id = call.arguments['id'];
        final settings = Alarm.getAlarm(id);
        if (settings != null) Alarm.ringStream.add(settings);
      }
    } catch (e) {
      alarmPrint('[DEV] Handle method call "${call.method}" error: $e');
    }
  }

  /// Creates isolate communication channel and set alarm at given [dateTime].
  static Future<bool> set(
    AlarmSettings settings,
    void Function()? onRing,
  ) async {
    try {
      final delay = settings.dateTime.difference(DateTime.now());

      final res = await platform.invokeMethod(
        'setAlarm',
        {
          'id': settings.id,
          'delayInSeconds': delay.inSeconds,
          'assetAudioPath': settings.assetAudioPath,
          'loopAudio': settings.loopAudio,
          'vibrate': settings.vibrate,
          'volume': settings.volumeMax ? 1.0 : -1.0,
          'fadeDuration': settings.fadeDuration,
          'notificationTitle': settings.notificationTitle,
          'notificationBody': settings.notificationBody,
          'fullScreenIntent': settings.androidFullScreenIntent,
        },
      );
      alarmPrint('[DEV] setAlarm method channel invoked, returned: $res');
    } catch (e) {
      throw AlarmException('nativeAndroidAlarm error: $e');
    }

    if (settings.enableNotificationOnKill && !hasOtherAlarms) {
      try {
        await platform.invokeMethod(
          'setNotificationOnKillService',
          {
            'title': AlarmStorage.getNotificationOnAppKillTitle(),
            'description': AlarmStorage.getNotificationOnAppKillBody(),
          },
        );
        alarmPrint('NotificationOnKillService enabled with success');
      } catch (e) {
        throw AlarmException('NotificationOnKillService error: $e');
      }
    }

    return true;
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    final res = await platform.invokeMethod('stopAlarm', {'id': id});
    alarmPrint('[DEV] stopAlarm method channel invoked, returned: $res');
    if (!hasOtherAlarms) stopNotificationOnKillService();
    return res;
  }

  static Future<bool> isRinging(int id) async {
    final res = await platform.invokeMethod('isRinging', {'id': id});
    return res;
  }

  static Future<void> stopNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
      alarmPrint('NotificationOnKillService disabled with success');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
