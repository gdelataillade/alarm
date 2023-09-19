import 'alarm_settings.dart';

class NotificationEvent {
  NotificationEvent(this.alarmSettings, this.action, {this.snoozed = false});
  final AlarmSettings alarmSettings;
  final NotificationAction action;
  final bool snoozed;
}

enum NotificationAction {
  dismiss,
  snooze;

  /// Tries to parse [name] into a [NotificationAction]. When it fails, defaults
  /// to [NotificationAction.dismiss].
  static NotificationAction from(String? name) {
    final action = NotificationAction.values
        .where(
          (e) => e.name == name,
        )
        .firstOrNull;

    if (action == null) {
      return NotificationAction.dismiss;
    }

    return action;
  }
}
