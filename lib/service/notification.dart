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
import 'package:flutter/material.dart';
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
  static const String _backgroundPort = "alarm-notification-com";

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
  Future<void> init({
    String snoozeLabel = "Snooze",
    String dismissLabel = "Dismiss",
    bool forceRegisterPort = true,
  }) async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
        onDidReceiveLocalNotification: onSelectNotificationOldIOS,
        notificationCategories: [
          DarwinNotificationCategory(
            _categoryDefault,
            actions: [
              DarwinNotificationAction.plain(
                NotificationAction.dismiss.name,
                dismissLabel,
              ),
            ],
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
              DarwinNotificationAction.plain(
                NotificationAction.dismiss.name,
                dismissLabel,
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
    _registerPort(forceRegisterPort: forceRegisterPort);
  }

  @pragma('vm:entry-point')
  static onSelectNotificationBackground(
    NotificationResponse notificationResponse,
  ) async {
    alarmPrint('[NOTIFICATION] notification selected in background');
    final action = NotificationAction.from(notificationResponse.actionId);
    switch (action) {
      case NotificationAction.snooze:
        // Handle in isolate to prevent OS from killing the app during execution
        alarmPrint('[NOTIFICATION] + handling SNOOZE in the background');
        await onSnoozeInBackground(notificationResponse);
        return;

      case NotificationAction.dismiss:
        // Handle in isolate to prevent OS from killing the app during execution
        alarmPrint('[NOTIFICATION] + handling DISMISS in the background');
        await onDismissInBackground(notificationResponse);
        return;

      default:
        await onActionInBackground(notificationResponse);
    }
  }

  /// Snoozes the alarm while running in a background isolate.
  static Future<void> onSnoozeInBackground(
    NotificationResponse notificationResponse,
  ) async {
    final port = IsolateNameServer.lookupPortByName(_backgroundPort);
    bgLogPrint(port, 'SNOOZE button selected');

    if (notificationResponse.id != null) {
      await Alarm.snooze(notificationResponse.id!);
    } else {
      await Alarm.snoozeAll();
    }

    port?.send(PortMessage.notification(notificationResponse).serialize());
  }

  /// Dismisses the alarm while running in a background isolate.
  static Future<void> onDismissInBackground(
    NotificationResponse notificationResponse,
  ) async {
    final port = IsolateNameServer.lookupPortByName(_backgroundPort);
    bgLogPrint(port, 'DISMISS button selected');

    if (notificationResponse.id != null) {
      await Alarm.stop(notificationResponse.id!);
    } else {
      await Alarm.stopAll();
    }

    port?.send(PortMessage.notification(notificationResponse).serialize());
  }

  /// Default background handler for all types of notification actions.
  static Future<void> onActionInBackground(
    NotificationResponse notificationResponse,
  ) async {
    final port = IsolateNameServer.lookupPortByName(_backgroundPort);
    if (port != null) {
      alarmPrint('[NOTIFICATION] + delegating to regular callback');
      port.send(PortMessage.notification(notificationResponse).serialize());
    } else {
      alarmPrint('[NOTIFICATION] + port closed, try to run in the background');
      onSelectNotification(notificationResponse);
    }
  }

  // Callback to stop the alarm when the notification is opened.
  static onSelectNotification(
    NotificationResponse notificationResponse, {
    bool calledFromIsolate = false,
  }) async {
    alarmPrint(
      '[NOTIFICATION] notification selected with payload: ${notificationResponse.payload}',
    );
    NotificationPayload? payload =
        NotificationPayload.tryDeserialize(notificationResponse.payload);

    if (payload?.type == NotificationType.bedtime) {
      onSelectBedtimeNotification(notificationResponse, payload!);
      return;
    }

    if (!calledFromIsolate) {
      // Only dismiss the alarm if not called from isolate. Isolate already
      // handles that.
      if (notificationResponse.id != null) {
        await Alarm.stop(notificationResponse.id!);
      } else {
        await Alarm.stopAll();
      }
    }

    final settings = await Alarm.getAlarm(notificationResponse.id ?? 0);
    if (settings != null) {
      alarmPrint('[NOTIFICATION] + broadcasting alarm: $settings');
      final action = NotificationAction.from(notificationResponse.actionId);
      final event = NotificationEvent(settings, action);
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
      alarmPrint('[NOTIFICATION] + broadcasting bedtime: $settings');
      final action = NotificationAction.from(notificationResponse.actionId);
      final event = NotificationEvent(settings, action);
      bedtimeNotificationStream.add(event);
    }
  }

  /// Callback to stop the alarm when the notification is opened for iOS
  /// versions older than 10.
  static onSelectNotificationOldIOS(
    int id,
    String? title,
    String? body,
    String? rawPayload,
  ) async {
    NotificationPayload? payload =
        NotificationPayload.tryDeserialize(rawPayload);

    if (payload?.type == NotificationType.bedtime) {
      onSelectBedtimeNotificationOldIOS(id, title, body, payload);
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

  static DateTime nextDateTime(TimeOfDay time) {
    final now = DateTime.now();
    var result = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (result.isBefore(now)) {
      result = result.add(const Duration(days: 1));
    }

    return result;
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
    String dismissLabel = 'Dismiss',
    int? alarmId,
    DateTime? nowAtStartup,
    Duration? autoDismiss,
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
      timeoutAfter: autoDismiss?.inMilliseconds,
      actions: [
        if (snooze && type == NotificationType.alarm)
          AndroidNotificationAction(
            NotificationAction.snooze.name,
            snoozeLabel,
          ),
        AndroidNotificationAction(
          NotificationAction.dismiss.name,
          dismissLabel,
        ),
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
  static void _registerPort({bool forceRegisterPort = true}) {
    try {
      final port = ReceivePort();
      final success = IsolateNameServer.registerPortWithName(
        port.sendPort,
        _backgroundPort,
      );

      if (!success) {
        // Port already registered
        if (!forceRegisterPort) {
          alarmPrint('[NOTIFICATION] Reusing existing port');
          return;
        }

        IsolateNameServer.removePortNameMapping(_backgroundPort);
        IsolateNameServer.registerPortWithName(
          port.sendPort,
          _backgroundPort,
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
              '[NOTIFICATION] delegating notification response from isolate',
            );
            onSelectNotification(
              portMessage.notificationResponse!,
              calledFromIsolate: true,
            );
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
