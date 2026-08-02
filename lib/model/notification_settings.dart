import 'dart:ui';

import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_settings.g.dart';

/// Model for notification settings.
@JsonSerializable()
class NotificationSettings extends Equatable {
  /// Constructs an instance of `NotificationSettings`.
  ///
  /// Open PR if you want more features.
  const NotificationSettings({
    required this.title,
    required this.body,
    this.stopButton,
    this.androidSnoozeButton,
    this.icon,
    this.iconColor,
    this.keepNotificationAfterAlarmEnds = false,
    this.androidStopAlarmOnDismiss = true,
  });

  /// Converts the JSON object to a `NotificationSettings` instance.
  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  /// Title of the notification to be shown when alarm is triggered.
  final String title;

  /// Body of the notification to be shown when alarm is triggered.
  final String body;

  /// The text to display on the stop button of the notification.
  ///
  /// Won't work on iOS if app was killed.
  /// If null, button will not be shown. Null by default.
  final String? stopButton;

  /// The text to display on the snooze button of the notification.
  ///
  /// **Android only.** Shown only when `AlarmSettings.androidSnoozeDuration`
  /// also gives it a duration; a label alone describes nothing the platform
  /// can perform.
  ///
  /// If null, button will not be shown. Null by default.
  final String? androidSnoozeButton;

  /// The icon to display on the notification.
  ///
  /// **Only customizable for Android. On iOS, it will use app default icon.**
  ///
  /// This refers to the small icon that is displayed in the
  /// status bar and next to the notification content in both collapsed
  /// and expanded views.
  ///
  /// Note that the icon must be monochrome and on a transparent background and
  /// preferably 24x24 dp in size.
  ///
  /// **Only PNG and XML formats are supported at the moment.
  /// Please open an issue to request support for more formats.**
  ///
  /// You must add your icon to your Android project's `res/drawable` directory.
  /// Example: `android/app/src/main/res/drawable/notification_icon.png`
  ///
  /// And pass: `icon: notification_icon` without the file extension.
  ///
  /// If `null`, the default app icon will be used.
  /// Defaults to `null`.
  final String? icon;

  /// The color of the notification icon.
  ///
  /// **Only customizable for Android. On iOS, app default icon will be shown.**
  ///
  /// The icon is monochrome (light or dark) in the status bar but in expanded
  /// view it gets a background color that can be set with this parameter.
  ///
  /// If `null`, the icon will have a default color.
  /// Defaults to `null`.
  @_ColorJsonConverter()
  final Color? iconColor;

  /// Keeps the notification banner visible even after the alarm sound ends.
  ///
  /// **iOS only for now.** On Android, the notification already stays
  /// visible after the sound ends because it is tied to the foreground
  /// service.
  ///
  /// If `true`, when the alarm finishes ringing automatically (non-looping
  /// alarms), the delivered notification will not be dismissed so the user
  /// can still see it in the notification center.
  ///
  /// Defaults to `false`.
  final bool keepNotificationAfterAlarmEnds;

  /// Whether swiping the notification away also stops the alarm.
  ///
  /// **Android only.** iOS has no equivalent dismissal action.
  ///
  /// Android 13 made foreground service notifications user-dismissible, so
  /// `setOngoing(true)` no longer keeps the alarm notification pinned: it can
  /// be swiped out of the shade like any other. When this is `true` that swipe
  /// runs the same stop action as the notification's stop button.
  ///
  /// Set it to `false` if a stray swipe must not be able to silence an alarm.
  /// Note that the notification is then gone while the alarm keeps ringing, so
  /// the app should offer another way to stop it (for example a ringing screen
  /// of its own, reachable from the launcher).
  ///
  /// Defaults to `true`, which is how the plugin has behaved since 5.0.3.
  final bool androidStopAlarmOnDismiss;

  /// Converts the `NotificationSettings` instance to a JSON object.
  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  /// Converts to wire datatype which is used for host platform communication.
  NotificationSettingsWire toWire() => NotificationSettingsWire(
        title: title,
        body: body,
        stopButton: stopButton,
        androidSnoozeButton: androidSnoozeButton,
        icon: icon,
        iconColorAlpha: iconColor?.a,
        iconColorRed: iconColor?.r,
        iconColorGreen: iconColor?.g,
        iconColorBlue: iconColor?.b,
        keepNotificationAfterAlarmEnds: keepNotificationAfterAlarmEnds,
        androidStopAlarmOnDismiss: androidStopAlarmOnDismiss,
      );

  /// Creates a copy of this notification settings but with the given fields
  /// replaced with the new values.
  NotificationSettings copyWith({
    String? title,
    String? body,
    String? stopButton,
    String? Function()? androidSnoozeButton,
    String? icon,
    Color? iconColor,
    bool? keepNotificationAfterAlarmEnds,
    bool? androidStopAlarmOnDismiss,
  }) {
    return NotificationSettings(
      title: title ?? this.title,
      body: body ?? this.body,
      stopButton: stopButton ?? this.stopButton,
      // Wrapped so a caller can remove the snooze action; the older nullable
      // fields keep their existing signatures for compatibility.
      androidSnoozeButton: androidSnoozeButton != null
          ? androidSnoozeButton()
          : this.androidSnoozeButton,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      keepNotificationAfterAlarmEnds:
          keepNotificationAfterAlarmEnds ?? this.keepNotificationAfterAlarmEnds,
      androidStopAlarmOnDismiss:
          androidStopAlarmOnDismiss ?? this.androidStopAlarmOnDismiss,
    );
  }

  @override
  List<Object?> get props => [
        title,
        body,
        stopButton,
        androidSnoozeButton,
        icon,
        iconColor,
        keepNotificationAfterAlarmEnds,
        androidStopAlarmOnDismiss,
      ];
}

/// Encodes a [Color] as its 32-bit ARGB integer.
///
/// `Color` has no JSON representation of its own, so without this the
/// generator cannot build `fromJson` for [NotificationSettings.iconColor].
/// The integer form matches what every previous plugin version wrote, so
/// alarms persisted before this converter existed still parse.
class _ColorJsonConverter implements JsonConverter<Color?, int?> {
  const _ColorJsonConverter();

  @override
  Color? fromJson(int? json) => json == null ? null : Color(json);

  @override
  int? toJson(Color? object) => object?.toARGB32();
}
