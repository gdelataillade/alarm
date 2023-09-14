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

  /// Stream when the alarm notification is selected.
  static final alarmNotificationStream = StreamController<AlarmSettings>();

  /// Stream when the bedtime notification is selected.
  static final bedtimeNotificationStream = StreamController<AlarmSettings>();

  /// Checks if a notification launched the app and if so, triggers the
  /// callback
  static Future<bool> checkNotificationLaunchedApp() async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await instance.localNotif.getNotificationAppLaunchDetails();

    final notificationResponse =
        notificationAppLaunchDetails?.notificationResponse;

    if (notificationResponse != null) {
      onSelectNotification(notificationResponse);
      return true;
    }
    return false;
  }

  static Future<bool> get didNotificationLaunchedApp async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await instance.localNotif.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails == null) {
      alarmPrint(
          '[NOTIFICATION] couln\'t find if app was launched by notification');
    }

    return notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;
  }

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
      onDidReceiveBackgroundNotificationResponse:
          onSelectNotificationBackground,
      onDidReceiveNotificationResponse: onSelectNotification,
    );
    tz.initializeTimeZones();
  }

  @pragma('vm:entry-point')
  static onSelectNotificationBackground(
          NotificationResponse notificationResponse) =>
      onSelectNotification(notificationResponse);

  // Callback to stop the alarm when the notification is opened.
  static onSelectNotification(NotificationResponse notificationResponse) async {
    alarmPrint(
      '[ALARM_NOTIFICATION] notification selected. Payload: ${notificationResponse.payload}',
    );
    if (notificationResponse.payload != null) {
      final alarmId = int.tryParse(notificationResponse.payload!);
      onSelectBedtimeNotification(alarmId, notificationResponse);
      return;
    }

    final settings = Alarm.getAlarm(notificationResponse.id ?? 0);
    if (settings != null) {
      alarmNotificationStream.add(settings);
    }

    await stopAlarm(notificationResponse.id);
  }

  static onSelectBedtimeNotification(
      int? alarmId, NotificationResponse notificationResponse) async {
    if (alarmId == null) {
      return;
    }

    final settings = Alarm.getAlarm(alarmId);
    if (settings != null) {
      bedtimeNotificationStream.add(settings);
    }
  }

  // Callback to stop the alarm when the notification is opened for iOS versions older than 10.
  static onSelectNotificationOldIOS(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    if (payload != null) {
      final alarmId = int.tryParse(payload);
      onSelectBedtimeNotificationOldIOS(alarmId, id, title, body, payload);
      return;
    }

    final settings = Alarm.getAlarm(id);
    if (settings != null) {
      alarmNotificationStream.add(settings);
    }

    await stopAlarm(id);
  }

  static onSelectBedtimeNotificationOldIOS(
    int? alarmId,
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    if (alarmId == null) {
      return;
    }

    final settings = Alarm.getAlarm(alarmId);
    if (settings != null) {
      bedtimeNotificationStream.add(settings);
    }
  }

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

    try {
      result = defaultTargetPlatform == TargetPlatform.android
          ? await localNotif
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestPermission()
          : await localNotif
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      alarmPrint('Failure during checking notification permission. $e');
    }

    return result ?? true;
  }

  /// Shows notification permission request. May throw.
  Future<bool> requestPermissionUnguarded() async {
    final result = defaultTargetPlatform == TargetPlatform.android
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

  tz.TZDateTime nextInstanceOfTime(
    DateTime dateTime, [
    DateTime? nowAtStartup,
  ]) {
    nowAtStartup ??= DateTime.now();
    if (dateTime.isBefore(nowAtStartup)) {
      dateTime = dateTime.add(const Duration(days: 1));
    } else if (dateTime.isBefore(DateTime.now())) {
      // Processing took longer than expected, trigger the notification now
      dateTime = DateTime.now().add(const Duration(seconds: 1));
    }

    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Schedules notification at the given [dateTime].
  static Future<void> scheduleNotification({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    bool playSound = false,
    bool enableLights = false,
    int? alarmId,
    DateTime? nowAtStartup,
  }) async {
    final iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: playSound,
    );

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: playSound,
      enableLights: enableLights,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = instance.nextInstanceOfTime(dateTime, nowAtStartup);

    final hasPermission = await instance.requestPermission();
    if (!hasPermission) {
      alarmPrint('Notification permission not granted');
      return;
    }

    try {
      await instance.localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(zdt.toUtc(), tz.UTC),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: alarmId?.toString(),
      );
      alarmPrint(
        'Notification with id $id scheduled successfuly at $zdt (GMT - Zulu time)',
      );
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
