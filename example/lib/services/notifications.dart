import 'dart:async';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart';

class Notifications {
  Notifications() {
    init();
  }
  static const _iosCategoryId = 'sample_category';
  static final _log = Logger('Notifications');

  final _plugin = FlutterLocalNotificationsPlugin();
  final _initCompleter = Completer<void>();

  Future<void> init() async {
    tz.initializeTimeZones();
    setLocalLocation(getLocation('America/New_York'));

    final success = await _plugin.initialize(
      InitializationSettings(
        iOS: DarwinInitializationSettings(
          notificationCategories: [
            DarwinNotificationCategory(
              _iosCategoryId,
              actions: [
                DarwinNotificationAction.plain(
                  'sample_action',
                  'Sample Action',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
              options: {
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
                DarwinNotificationCategoryOption.hiddenPreviewShowSubtitle,
                DarwinNotificationCategoryOption.allowAnnouncement,
              },
            ),
          ],
        ),
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: notificationTapForeground,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (success ?? false) {
      _log.info('Notifications initialized');
    } else {
      _log.severe('Failed to initialize notifications');
    }
    _initCompleter.complete();
  }

  Future<void> showNotification() async {
    await _initCompleter.future;

    await _plugin.show(
      _randomId,
      'Notification Title',
      'This is the notification body.',
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          badgeNumber: 1,
          categoryIdentifier: _iosCategoryId,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        android: AndroidNotificationDetails('sample_channel', 'Sample Channel'),
      ),
      payload: 'payload',
    );
    _log.info('Notification shown.');
  }

  Future<void> scheduleNotification() async {
    await _initCompleter.future;

    await _plugin.zonedSchedule(
      _randomId,
      'Delayed Notification Title',
      'This is the notification body shown after 5s.',
      TZDateTime.now(local).add(const Duration(seconds: 5)),
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          badgeNumber: 1,
          categoryIdentifier: _iosCategoryId,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        android: AndroidNotificationDetails('sample_channel', 'Sample Channel'),
      ),
      androidScheduleMode: AndroidScheduleMode.exact,
      payload: 'payload',
    );
    _log.info('Notification scheduled.');
  }

  int get _randomId {
    const min = -0x80000000;
    const max = 0x7FFFFFFF;
    return Random().nextInt(max - min) + min;
  }

  @pragma('vm:entry-point')
  static void notificationTapForeground(
    NotificationResponse notificationResponse,
  ) {
    _log.info('notificationTapForeground: $notificationResponse');
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    _log.info('notificationTapBackground: $notificationResponse');
  }
}
