import 'package:flutter/widgets.dart';

@immutable

/// Model for notification action settings.
class NotificationActionSettings {
  /// Constructs an instance of `NotificationActionSettings`.
  const NotificationActionSettings({
    this.hasStopButton = false,
    this.hasSnoozeButton = false,
    this.stopButtonText = 'Stop',
    this.snoozeButtonText = 'Snooze',
    this.snoozeDurationInSeconds = 9 * 60,
  });

  /// Constructs an instance of `NotificationActionSettings` from a JSON object.
  factory NotificationActionSettings.fromJson(Map<String, dynamic> json) =>
      NotificationActionSettings(
        hasStopButton: json['hasStopButton'] as bool? ?? false,
        hasSnoozeButton: json['hasSnoozeButton'] as bool? ?? false,
        snoozeDurationInSeconds:
            json['snoozeDurationInSeconds'] as int? ?? 9 * 60,
      );

  /// Whether to show the stop button.
  final bool hasStopButton;

  /// Whether to show the snooze button.
  final bool hasSnoozeButton;

  /// The text to display on the stop button. Defaults to 'Stop'.
  final String stopButtonText;

  /// The text to display on the snooze button. Defaults to 'Snooze'.
  final String snoozeButtonText;

  /// The snooze duration in seconds. Defaults to 9 minutes.
  final int snoozeDurationInSeconds;

  /// Whether the notification action buttons are enabled.
  bool get enabled => hasStopButton || hasSnoozeButton;

  /// Converts the `NotificationActionSettings` instance to a JSON object.
  Map<String, dynamic> toJson() => {
        'hasStopButton': hasStopButton,
        'hasSnoozeButton': hasSnoozeButton,
        'stopButtonText': stopButtonText,
        'snoozeButtonText': snoozeButtonText,
        'snoozeDurationInSeconds': snoozeDurationInSeconds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationActionSettings &&
          runtimeType == other.runtimeType &&
          hasStopButton == other.hasStopButton &&
          hasSnoozeButton == other.hasSnoozeButton &&
          stopButtonText == other.stopButtonText &&
          snoozeButtonText == other.snoozeButtonText &&
          snoozeDurationInSeconds == other.snoozeDurationInSeconds;

  @override
  int get hashCode => Object.hash(
        hasStopButton,
        hasSnoozeButton,
        stopButtonText,
        snoozeButtonText,
        snoozeDurationInSeconds,
      );

  @override
  String toString() =>
      '''NotificationActionSettings(hasStopButton: $hasStopButton, hasSnoozeButton: $hasSnoozeButton, stopButtonText: $stopButtonText, snoozeButtonText: $snoozeButtonText, snoozeDurationInSeconds: $snoozeDurationInSeconds)''';
}
