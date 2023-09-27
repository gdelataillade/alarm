import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/message_type.dart';
import 'package:alarm/model/port_message.dart';
import 'package:alarm/model/notification_action.dart';
import 'package:alarm/model/notification_payload.dart';
import 'package:alarm/model/notification_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// comes from. He also can tap the notification to open directly the app.
class AlarmNotification {
  static final instance = AlarmNotification._();

  static const String _categoryWithSnooze = "snooze";
  static const String _categoryDefault = "default";
  static const String _backgroundComPortName = "alarm-notification-com";

  final localNotif = FlutterLocalNotificationsPlugin();

  /// Stream when the alarm notification is selected.
  static final alarmNotificationStream = StreamController<NotificationEvent>();

  /// Stream when the bedtime notification is selected.
  static final bedtimeNotificationStream =
      StreamController<NotificationEvent>();

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
    return notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;
  }

  AlarmNotification._();

  /// Adds configuration for local notifications and initialize service.
  Future<void> init({String snoozeLabel = "Snooze"}) async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
        onDidReceiveLocalNotification: onSelectNotificationOldIOS,
        notificationCategories: [
          const DarwinNotificationCategory(
            _categoryDefault,
            options: {
              DarwinNotificationCategoryOption.allowAnnouncement,
            },
          ),
          DarwinNotificationCategory(
            _categoryWithSnooze,
            actions: [
              DarwinNotificationAction.plain(
                NotificationAction.snooze.name,
                snoozeLabel,
              ),
            ],
            options: {
              DarwinNotificationCategoryOption.allowAnnouncement,
            },
          ),
        ]);

    final initializationSettings = InitializationSettings(
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
    _registerPort();
  }

  @pragma('vm:entry-point')
  static onSelectNotificationBackground(
    NotificationResponse notificationResponse,
  ) async {
    alarmPrint('[NOTIFICATION] notification selected in background');
    final action = NotificationAction.from(notificationResponse.actionId);
    if (action == NotificationAction.snooze) {
      // Handle alarm snooze in here instead of delegating it to ensure the OS
      // doesn't kill the app in the middle
      alarmPrint('[NOTIFICATION] + handling snooze in the background');
      await onSnoozeSelectedBackground(notificationResponse);
      return;
    }

    final callerPort =
        IsolateNameServer.lookupPortByName(_backgroundComPortName);
    if (callerPort != null) {
      alarmPrint('[NOTIFICATION] + delegating to regular callback');
      callerPort
          .send(PortMessage.notification(notificationResponse).serialize());
    } else {
      alarmPrint(
        '[NOTIFICATION] + port was closed, attempting to handle in the background',
      );
      await Alarm.init();
      onSelectNotification(notificationResponse);
    }
  }

  /// Snoozes the alarm while running in a background isolate.
  static Future<void> onSnoozeSelectedBackground(
      NotificationResponse notificationResponse) async {
    final callerPort =
        IsolateNameServer.lookupPortByName(_backgroundComPortName);
    bgLogPrint(callerPort, 'snooze button selected');
    await Alarm.init();
    final alarmSettings = await Alarm.getAlarm(notificationResponse.id ?? 0);
    if (alarmSettings != null) {
      bgLogPrint(callerPort, 'trying to reschedule the alarm');
      await Alarm.set(
        alarmSettings: alarmSettings.copyWith(
          dateTime: DateTime.now().add(alarmSettings.snoozeDuration),
        ),
      );
    } else {
      bgLogPrint(callerPort, 'Failed! could\'t find alarm');
    }
  }

  // Callback to stop the alarm when the notification is opened.
  static onSelectNotification(NotificationResponse notificationResponse) async {
    alarmPrint(
      '[NOTIFICATION] notification selected with payload: ${notificationResponse.payload}',
    );
    NotificationPayload? payload;
    if (notificationResponse.payload?.isNotEmpty == true) {
      payload = NotificationPayload.deserialize(notificationResponse.payload!);
    }

    if (payload?.type == NotificationType.bedtime) {
      onSelectBedtimeNotification(notificationResponse, payload!);
      return;
    }

    final settings = await Alarm.getAlarm(notificationResponse.id ?? 0);
    if (settings != null) {
      final action = NotificationAction.from(notificationResponse.actionId);
      final event = NotificationEvent(
        settings,
        action,
        snoozed: action == NotificationAction.snooze,
      );
      alarmNotificationStream.add(event);
    }
  }

  static onSelectBedtimeNotification(
    NotificationResponse notificationResponse,
    NotificationPayload payload,
  ) async {
    alarmPrint(
      '[NOTIFICATION] + bedtime notification selected for alarm: ${payload.alarmId}',
    );
    if (payload.alarmId == null) {
      return;
    }

    final settings = await Alarm.getAlarm(payload.alarmId!);
    if (settings != null) {
      final action = NotificationAction.from(notificationResponse.actionId);
      final event = NotificationEvent(
        settings,
        action,
        snoozed: action == NotificationAction.snooze,
      );

      bedtimeNotificationStream.add(event);
    }
  }

  /// Callback to stop the alarm when the notification is opened for iOS
  /// versions older than 10.
  static onSelectNotificationOldIOS(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    NotificationPayload? payloadModel;
    if (payload?.isNotEmpty == true) {
      payloadModel = NotificationPayload.deserialize(payload!);
    }

    if (payloadModel?.type == NotificationType.bedtime) {
      onSelectBedtimeNotificationOldIOS(id, title, body, payloadModel);
      return;
    }

    final settings = await Alarm.getAlarm(id);
    if (settings != null) {
      final event = NotificationEvent(
        settings,
        NotificationAction.dismiss,
      );
      alarmNotificationStream.add(event);
    }

    await stopAlarm(id);
  }

  static onSelectBedtimeNotificationOldIOS(
    int id,
    String? title,
    String? body,
    NotificationPayload? payload,
  ) async {
    if (payload?.alarmId == null) {
      return;
    }

    final settings = await Alarm.getAlarm(payload!.alarmId!);
    if (settings != null) {
      final event = NotificationEvent(
        settings,
        NotificationAction.dismiss,
      );
      bedtimeNotificationStream.add(event);
    }
  }

  /// Stops the alarm.
  static Future<void> stopAlarm(int? id) async {
    if (id == null) {
      return;
    }

    final alarm = await Alarm.getAlarm(id);
    if (alarm?.stopOnNotificationOpen == true) {
      await Alarm.stop(id);
    }
  }

  /// Shows notification permission request. Defaults to `true` when it fails to
  /// check while the app is in the background.
  Future<bool> requestPermission() async {
    bool? enabled;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android
        final platform = localNotif.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        enabled = await platform?.areNotificationsEnabled();
        if (enabled == null || !enabled) {
          enabled = await platform?.requestPermission();
        }
      } else {
        // iOS
        enabled = await localNotif
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      alarmPrint(
        'Failure during checking notification permission. Most likely because the app is in the background',
      );
    }

    return enabled ?? true;
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
    required NotificationType type,
    bool playSound = false,
    bool enableLights = false,
    bool snooze = false,
    String snoozeLabel = 'Snooze',
    int? alarmId,
    DateTime? nowAtStartup,
  }) async {
    final iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: playSound,
      categoryIdentifier: snooze ? _categoryWithSnooze : _categoryDefault,
    );

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'alarm',
      'alarm_plugin',
      channelDescription: 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: playSound,
      enableLights: enableLights,
      actions: [
        if (snooze && type == NotificationType.alarm)
          AndroidNotificationAction(NotificationAction.snooze.name, snoozeLabel)
      ],
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
        payload: NotificationPayload(
          type: type,
          alarmId: alarmId,
        ).serialize(),
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

  /// Attempt to proxy the log to the main app or default to console
  static bgLogPrint(SendPort? port, String message) => (port != null)
      ? port.send(PortMessage.log(message).serialize())
      : alarmPrint('[NOTIFICATION] $message');

  /// Register port to communicate with [Isolate] when a notification is
  /// selected while the app is in the background.
  static void _registerPort() {
    try {
      final port = ReceivePort();
      final success = IsolateNameServer.registerPortWithName(
        port.sendPort,
        _backgroundComPortName,
      );

      if (!success) {
        // Port already registered
        IsolateNameServer.removePortNameMapping(_backgroundComPortName);
        IsolateNameServer.registerPortWithName(
          port.sendPort,
          _backgroundComPortName,
        );
      }

      port.listen((rawMessage) {
        final portMessage = PortMessage.deserialize(rawMessage);
        switch (portMessage.type) {
          case MessageType.log:
            alarmPrint(
                '[NOTIFICATION] message from isolate: ${portMessage.message}');
            break;

          case MessageType.notification:
            alarmPrint(
              '[NOTIFICATION] delegating notification response from isolate: ${portMessage.message}',
            );
            onSelectNotification(portMessage.notificationResponse!);
            break;

          default:
            alarmPrint(
              '[NOTIFICATION] unhandled message from isolate: $rawMessage',
            );
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }
  }
}
