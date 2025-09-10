import 'package:alarm/src/base_alarm.dart';
import 'package:alarm/utils/alarm_handler.dart';
import 'package:logging/logging.dart';

/// Uses method channel to interact with the native platform for Android.
class AndroidAlarm extends BaseAlarm {
  /// Creates an [AndroidAlarm] instance.
  AndroidAlarm() : super(Logger('AndroidAlarm'));

  /// Disable the notification on kill service (Android-only).
  Future<void> disableWarningNotificationOnKill() => BaseAlarm.api
      .disableWarningNotificationOnKill()
      .catchError(AlarmExceptionHandlers.catchError<void>);

// Insert other Android platform specific code..
}
