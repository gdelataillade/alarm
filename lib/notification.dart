// ignore_for_file: avoid_print

import 'dart:developer';
import 'package:alarm/android_alarm.dart';
import 'package:alarm/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'alarm.dart';

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// come from. He also can tap the notification to open directly the app.
class Notification {
  Notification._();

  static final instance = Notification._();

  /// A unique identifier because it can be only one alarm.
  static const alarmId = 888;
  final FlutterLocalNotificationsPlugin localNotif =
  FlutterLocalNotificationsPlugin();

  /// Add configuration for local notifications and initialize.
  Future<void> init() async {
    const initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory('alarm', actions: [
            DarwinNotificationAction.text(
              '0',
              'snooze',
              buttonTitle: 'snooze',
            ),
            DarwinNotificationAction.text(
              '1',
              'stop',
              buttonTitle: 'stop',
            ),
          ])
        ],
        onDidReceiveLocalNotification: onDidReceiveLocalNotification);
    InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await localNotif.initialize(initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground);
    tz.initializeTimeZones();
  }

  static void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    log('------------------------------------onDidReceiveLocalNotification------------------------------------');
    await SharedPreference.init();
    if (id == 1) {
      AndroidAlarm.stop();
    }
    if (id == 0) {
      log('click on snooze');
      AndroidAlarm.stop();
      Alarm.set(
        alarmDateTime: DateTime.now().add(const Duration(minutes: 10)),
        assetAudio: SharedPreference.getAudioAssets(),
        loopAudio: SharedPreference.getLoopAudio(),
        onRing: () {},
        notifTitle: title,
        notifBody: body,
      );
    }
  }

  static void onDidReceiveNotificationResponse(
      NotificationResponse? notificationResponse) {
    log('------------------------------------onDidReceiveNotificationResponse------------------------------------');
    log('notificationResponse : $notificationResponse');
  }

  /// Show notification permission request.
  Future<bool> requestPermission() async {
    final result = await localNotif
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return result ?? false;
  }

  tz.TZDateTime nextInstanceOfTime(Time time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ),
      tz.local,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedule notification for iOS at the given time.
  Future<void> scheduleIOSAlarmNotif({
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentSound: false,
      presentAlert: false,
      presentBadge: false,
    );
    const platformChannelSpecifics = NotificationDetails(
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(Time(dateTime.hour, dateTime.minute));

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      print("[Alarm] Notification permission denied");
      return;
    }

    try {
      await localNotif.zonedSchedule(
          alarmId, title, body, zdt, platformChannelSpecifics,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: '$title ,, $body');
      print("[Alarm] Notification scheduled successfuly at ${zdt.toString()}");
    } catch (e) {
      print("[Alarm] Schedule notification error: $e");
    }
  }

  /// Show notification for Android instantly.
  Future<void> androidAlarmNotif(
      {required String title, required String body}) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'alarm', 'alarm',
        channelDescription: 'Alarm package',
        importance: Importance.max,
        priority: Priority.max,
        enableLights: true,
        playSound: false,
        actions: [
          AndroidNotificationAction('0', 'snooze'),
          AndroidNotificationAction('1', 'stop', cancelNotification: true),
        ]);

    const platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await localNotif.show(alarmId, title, body, platformChannelSpecifics,
        payload: '$title ,, $body');
  }

  /// Cancel notification. Called when the alarm is cancelled.
  Future<void> cancel() => localNotif.cancel(alarmId);
}

@pragma('vm:entry-point')
void notificationTapBackground(
    NotificationResponse notificationResponse) async {
  log('------------------------------------notificationTapBackground------------------------------------');
  await SharedPreference.init();
  if (notificationResponse.actionId == '1') {
    AndroidAlarm.stop();
  }
  if (notificationResponse.actionId == '0') {
    log('click on snooze');
    AndroidAlarm.stop();
    List<String> payload =
        notificationResponse.payload?.split(',,') ?? ['', ''];
    Alarm.set(
      alarmDateTime: DateTime.now().add(const Duration(minutes: 1)),
      assetAudio: 'assets/sample.mp3',
      loopAudio: SharedPreference.getLoopAudio(),
      onRing: () {},
      notifTitle: payload[0],
      notifBody: payload[1],
    );
  }
}
