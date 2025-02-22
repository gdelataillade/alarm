import 'package:alarm/alarm.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmPermissions {
  static final _log = Logger('AlarmPermissions');

  static Future<void> checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      _log.info('Requesting notification permission...');
      final res = await Permission.notification.request();
      _log.info(
        'Notification permission ${res.isGranted ? '' : 'not '}granted',
      );
    }
  }

  static Future<void> checkAndroidExternalStoragePermission() async {
    final status = await Permission.storage.status;
    if (status.isDenied) {
      _log.info('Requesting external storage permission...');
      final res = await Permission.storage.request();
      _log.info(
        'External storage permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  static Future<void> checkAndroidScheduleExactAlarmPermission() async {
    if (!Alarm.android) return;
    final status = await Permission.scheduleExactAlarm.status;
    _log.info('Schedule exact alarm permission: $status.');
    if (status.isDenied) {
      _log.info('Requesting schedule exact alarm permission...');
      final res = await Permission.scheduleExactAlarm.request();
      _log.info(
        'Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  static Future<void> checkLocationPermission() async {
    final status = await Permission.location.status;
    _log.info('Location permission: $status.');
    if (status.isDenied) {
      _log.info('Requesting location permission...');
      final res = await Permission.location.request();
      _log.info(
        'Location permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }

  static Future<void> checkBackgroundLocationPermission() async {
    final status = await Permission.locationAlways.status;
    _log.info('Background location permission: $status.');
    if (status.isDenied) {
      _log.info('Requesting background location permission...');
      final res = await Permission.locationAlways.request();
      _log.info(
        'Background location permission ${res.isGranted ? '' : 'not'} granted',
      );
    }
  }
}
