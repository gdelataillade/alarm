import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// comes from. He also can tap the notification to open directly the app.
class AlarmNotification {
  static final instance = AlarmNotification._();

  final localNotif = FlutterLocalNotificationsPlugin();

  AlarmNotification._();

  /// Adds configuration for local notifications and initialize service.
  Future<void> init() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await localNotif.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  /// Shows notification permission request.
  Future<bool> requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final res = await localNotif
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return res ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final res = await localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      return res ?? false;
    }
    return false;
  }

  tz.TZDateTime nextInstanceOfTime(DateTime dateTime) {
    final now = DateTime.now();

    if (dateTime.isBefore(now)) {
      dateTime = dateTime.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Schedules notification at the given [dateTime].
  Future<void> scheduleAlarmNotif({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    required bool fullScreenIntent,
  }) async {
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableLights: true,
      fullScreenIntent: fullScreenIntent,
      visibility: NotificationVisibility.public,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(dateTime);

    final hasNotificationPermission = await requestNotificationPermission();
    if (!hasNotificationPermission) {
      alarmPrint('Notification permission not granted');
    }

    try {
      await localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(zdt.toUtc(), tz.UTC),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      alarmPrint(
        'Notification with id $id scheduled successfuly at $zdt GMT',
      );
    } catch (e) {
      throw AlarmException('Schedule notification with id $id error: $e');
    }
  }

  /// Cancels notification. Called when the alarm is cancelled or
  /// when an alarm is overriden.
  Future<void> cancel(int id) => localNotif.cancel(id);
}
