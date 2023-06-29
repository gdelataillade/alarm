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
    String? _,
    String? __,
    String? ___,
  ) async =>
      await stopAlarm(id);

  /// Stops the alarm.
  static Future<void> stopAlarm(int? id) async {
    if (id != null &&
        Alarm.getAlarm(id)?.stopOnNotificationOpen != null &&
        Alarm.getAlarm(id)!.stopOnNotificationOpen) {
      await Alarm.stop(id);
    }
  }

  /// Shows notification permission request.
  Future<bool> requestPermission() async {
    bool? result;

    result = defaultTargetPlatform == TargetPlatform.android
        ? await localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestPermission()
        : await localNotif
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);

    return result ?? false;
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
  }) async {
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: false,
      enableLights: true,
    );

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(dateTime);

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
