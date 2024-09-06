import 'package:flutter/widgets.dart';

@immutable

/// Model for notification settings.
class NotificationSettings {
  /// Constructs an instance of `NotificationSettings`.
  ///
  /// Open PR if you want more features.
  const NotificationSettings({
    required this.title,
    required this.body,
    this.stopButton,
  });

  /// Constructs an instance of `NotificationSettings` from a JSON object.
  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      NotificationSettings(
        title: json['title'] as String,
        body: json['body'] as String,
        stopButton: json['stopButton'] as String?,
      );

  /// Title of the notification to be shown when alarm is triggered.
  final String title;

  /// Body of the notification to be shown when alarm is triggered.
  final String body;

  /// The text to display on the stop button of the notification.
  ///
  /// Won't work on iOS if app was killed.
  /// If null, button will not be shown. Null by default.
  final String? stopButton;

  /// Converts the `NotificationSettings` instance to a JSON object.
  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'stopButton': stopButton,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          body == other.body &&
          stopButton == other.stopButton;

  @override
  int get hashCode => Object.hash(
        title,
        body,
        stopButton,
      );

  @override
  String toString() => 'NotificationSettings: ${toJson()}';

  /// Creates a copy of this notification settings but with the given fields
  /// replaced with the new values.
  NotificationSettings copyWith({
    String? title,
    String? body,
    String? stopButton,
  }) {
    assert(title != null, 'NotificationSettings.title cannot be null');
    assert(body != null, 'NotificationSettings.body cannot be null');

    return NotificationSettings(
      title: title ?? this.title,
      body: body ?? this.body,
      stopButton: stopButton ?? this.stopButton,
    );
  }
}
