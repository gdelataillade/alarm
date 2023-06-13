import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// comes from. He also can tap the notification to open directly the app.
class AlarmNotification {
  AlarmNotification._();

  static final instance = AlarmNotification._();

  final FlutterLocalNotificationsPlugin localNotif =
      FlutterLocalNotificationsPlugin();

  /// Adds configuration for local notifications and initialize service.
  Future<void> init() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: onSelectNotificationOldIOS,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await localNotif.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
      onDidReceiveNotificationResponse: onSelectNotification,
    );
    tz.initializeTimeZones();
  }

  // Callback to stop the alarm when the notification is opened.
  static onSelectNotification(NotificationResponse notificationResponse) async {
    await stopAlarm(notificationResponse.id);
  }

  // Callback to stop the alarm when the notification is opened for iOS versions older than 10.
  static onSelectNotificationOldIOS(
    int? id,
    String? title,
    String? body,
    String? payload,
  ) async {
    await stopAlarm(id);
  }

  /// Stops the alarm
  static Future<void> stopAlarm(int? id) async {
    if (id != null &&
        Alarm.getAlarm(id)?.stopOnNotificationOpen != null &&
        Alarm.getAlarm(id)!.stopOnNotificationOpen) {
      await Alarm.stop(id);
    }
  }

  /// Shows notification permission request.
  Future<bool> requestPermission() async {
    late bool? result;

    if (defaultTargetPlatform == TargetPlatform.android) {
      result = await localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission();
    } else {
      result = await localNotif
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
    return result ?? false;
  }

  tz.TZDateTime nextInstanceOfTime(Time time) {
    final DateTime now = DateTime.now();

    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      time.second,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(scheduledDate, tz.local);
  }

  /// Schedules notification at the given [dateTime].
  Future<void> scheduleAlarmNotif({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: false,
      presentAlert: false,
      presentBadge: false,
    );

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      enableLights: true,
      playSound: false,
    );

    const platformChannelSpecifics = NotificationDetails(
      iOS: iOSPlatformChannelSpecifics,
      android: androidPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(
      Time(
        dateTime.hour,
        dateTime.minute,
        dateTime.second,
      ),
    );

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      alarmPrint('Notification permission not granted');
      return;
    }

    try {
      await localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(zdt.toUtc(), tz.UTC),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      alarmPrint('Notification with id $id scheduled successfuly at $zdt');
    } catch (e) {
      throw AlarmException('Schedule notification with id $id error: $e');
    }
  }

  /// Cancels notification. Called when the alarm is cancelled or
  /// when an alarm is overriden.
  Future<void> cancel(int id) async {
    await localNotif.cancel(id);
    alarmPrint('Notification with id $id canceled');
  }
}
