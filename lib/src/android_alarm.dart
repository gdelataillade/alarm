import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter/services.dart';

/// Uses method channel to interact with the native platform.
class AndroidAlarm {
  /// Method channel for the alarm operations.
  static const methodChannel = MethodChannel('com.gdelataillade.alarm/alarm');

  /// Event channel for the alarm events.
  static const eventChannel = EventChannel('com.gdelataillade.alarm/events');

  /// Whether there are other alarms set.
  static bool get hasOtherAlarms => Alarm.getAlarms().length > 1;

  /// Starts listening to the native alarm events.
  static void init() => listenToNativeEvents();

  /// Listens to the alarm events.
  static void listenToNativeEvents() {
    eventChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        try {
          final eventMap = Map<String, dynamic>.from(event as Map);
          final id = eventMap['id'] as int?;
          final method = eventMap['method'] as String?;
          if (id == null || method == null) return;

          switch (method) {
            case 'stop':
              await Alarm.reload(id);
            case 'ring':
              final settings = Alarm.getAlarm(id);
              if (settings != null) Alarm.ringStream.add(settings);
          }
        } catch (e) {
          alarmPrint('Error receiving alarm events: $e');
        }
      },
      onError: (dynamic error, StackTrace stackTrace) {
        alarmPrint('Error listening to alarm events: $error, $stackTrace');
      },
    );
  }

  /// Schedules a native alarm with given [settings] with its notification.
  static Future<bool> set(AlarmSettings settings) async {
    try {
      await methodChannel.invokeMethod(
        'setAlarm',
        settings.toJson(),
      );
    } catch (e) {
      throw AlarmException('AndroidAlarm.setAlarm error: $e');
    }

    alarmPrint(
      '''Alarm with id ${settings.id} scheduled at ${settings.dateTime}''',
    );

    return true;
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    try {
      final res =
          await methodChannel.invokeMethod('stopAlarm', {'id': id}) as bool;
      if (res) alarmPrint('Alarm with id $id stopped');
      if (!hasOtherAlarms) await stopNotificationOnKillService();
      return res;
    } catch (e) {
      alarmPrint('Failed to stop alarm: $e');
      return false;
    }
  }

  /// Checks if the alarm with given [id] is ringing.
  static Future<bool> isRinging(int id) async {
    try {
      final res =
          await methodChannel.invokeMethod('isRinging', {'id': id}) as bool;
      return res;
    } catch (e) {
      alarmPrint('Failed to check if alarm is ringing: $e');
      return false;
    }
  }

  /// Sets the native notification on app kill title and body.
  static Future<void> setNotificationOnAppKill(String title, String body) =>
      methodChannel.invokeMethod<void>(
        'setNotificationOnAppKillContent',
        {'title': title, 'body': body},
      );

  /// Disable the notification on kill service.
  static Future<void> stopNotificationOnKillService() async {
    try {
      await methodChannel.invokeMethod('stopNotificationOnKillService');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
