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
    this.icon,
    this.iconColor,
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
  final Color? iconColor;

  /// Converts the `NotificationSettings` instance to a JSON object.
  Map<String, dynamic> toJson() => _$NotificationSettingsToJson(this);

  /// Converts to wire datatype which is used for host platform communication.
  NotificationSettingsWire toWire() => NotificationSettingsWire(
        title: title,
        body: body,
        stopButton: stopButton,
        icon: icon,
        iconColorAlpha: iconColor?.a,
        iconColorRed: iconColor?.r,
        iconColorGreen: iconColor?.g,
        iconColorBlue: iconColor?.b,
      );

  /// Creates a copy of this notification settings but with the given fields
  /// replaced with the new values.
  NotificationSettings copyWith({
    String? title,
    String? body,
    String? stopButton,
    String? icon,
    Color? iconColor,
  }) {
    assert(title != null, 'NotificationSettings.title cannot be null');
    assert(body != null, 'NotificationSettings.body cannot be null');

    return NotificationSettings(
      title: title ?? this.title,
      body: body ?? this.body,
      stopButton: stopButton ?? this.stopButton,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
    );
  }

  @override
  List<Object?> get props => [title, body, stopButton, icon, iconColor];
}
