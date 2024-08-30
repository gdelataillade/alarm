import 'package:flutter/widgets.dart';

@immutable

/// Model for notification action settings.
class NotificationActionSettings {
  /// Constructs an instance of `NotificationActionSettings`.
  ///
  /// Open PR if you want more features.
  const NotificationActionSettings({
    this.hasStopButton = false,
    this.stopButtonText = 'Stop',
  });

  /// Constructs an instance of `NotificationActionSettings` from a JSON object.
  factory NotificationActionSettings.fromJson(Map<String, dynamic> json) =>
      NotificationActionSettings(
        hasStopButton: json['hasStopButton'] as bool? ?? false,
        stopButtonText: json['stopButtonText'] as String? ?? 'Stop',
      );

  /// Whether to show the stop button.
  final bool hasStopButton;

  /// The text to display on the stop button. Defaults to 'Stop'.
  final String stopButtonText;

  /// Converts the `NotificationActionSettings` instance to a JSON object.
  Map<String, dynamic> toJson() => {
        'hasStopButton': hasStopButton,
        'stopButtonText': stopButtonText,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationActionSettings &&
          runtimeType == other.runtimeType &&
          hasStopButton == other.hasStopButton &&
          stopButtonText == other.stopButtonText;

  @override
  int get hashCode => Object.hash(
        hasStopButton,
        stopButtonText,
      );

  @override
  String toString() => 'NotificationActionSettings: ${toJson()}';
}
