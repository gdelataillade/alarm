import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationSettings JSON', () {
    test('round trips all fields', () {
      const settings = NotificationSettings(
        title: 'Title',
        body: 'Body',
        stopButton: 'Stop',
        androidSnoozeButton: 'Snooze',
        icon: 'notification_icon',
        iconColor: Color(0xFF862778),
        keepNotificationAfterAlarmEnds: true,
        androidStopAlarmOnDismiss: false,
      );

      final restored = NotificationSettings.fromJson(settings.toJson());

      expect(restored, equals(settings));
    });

    test('encodes iconColor as its ARGB integer', () {
      // Pinned because the JSON is persisted: alarms saved by earlier versions
      // must keep parsing after iconColor moved to a JsonConverter.
      const settings = NotificationSettings(
        title: 'Title',
        body: 'Body',
        iconColor: Color(0xFF862778),
      );

      expect(settings.toJson()['iconColor'], 0xFF862778);
      expect(
        NotificationSettings.fromJson(const <String, dynamic>{
          'title': 'Title',
          'body': 'Body',
          'iconColor': 0xFF862778,
          'keepNotificationAfterAlarmEnds': false,
        }).iconColor,
        const Color(0xFF862778),
      );
    });

    test('round trips with optional fields absent', () {
      const settings = NotificationSettings(title: 'Title', body: 'Body');

      final restored = NotificationSettings.fromJson(settings.toJson());

      expect(restored.stopButton, isNull);
      expect(restored.icon, isNull);
      expect(restored.iconColor, isNull);
      expect(restored.keepNotificationAfterAlarmEnds, isFalse);
      expect(restored.androidStopAlarmOnDismiss, isTrue);
      expect(restored, equals(settings));
    });

    test('defaults androidStopAlarmOnDismiss to true when the key is absent',
        () {
      // Alarms persisted before this flag existed must keep stopping on a
      // dismiss, which is how the plugin has behaved since 5.0.3.
      const settings = NotificationSettings(title: 'Title', body: 'Body');
      final json = settings.toJson()..remove('androidStopAlarmOnDismiss');

      final restored = NotificationSettings.fromJson(json);

      expect(restored.androidStopAlarmOnDismiss, isTrue);
    });
  });

  group('NotificationSettings toWire', () {
    test('splits the icon color into ARGB channels', () {
      const settings = NotificationSettings(
        title: 'Title',
        body: 'Body',
        iconColor: Color(0xFF862778),
      );

      final wire = settings.toWire();

      expect(wire.title, 'Title');
      expect(wire.iconColorAlpha, 1.0);
      expect(wire.iconColorRed, closeTo(0x86 / 0xFF, 0.001));
      expect(wire.iconColorGreen, closeTo(0x27 / 0xFF, 0.001));
      expect(wire.iconColorBlue, closeTo(0x78 / 0xFF, 0.001));
    });

    test('carries androidStopAlarmOnDismiss across', () {
      const settings = NotificationSettings(
        title: 'Title',
        body: 'Body',
        androidStopAlarmOnDismiss: false,
      );

      expect(settings.toWire().androidStopAlarmOnDismiss, isFalse);
      expect(
        const NotificationSettings(title: 'Title', body: 'Body')
            .toWire()
            .androidStopAlarmOnDismiss,
        isTrue,
      );
    });

    test('leaves color channels null when no color is set', () {
      const settings = NotificationSettings(title: 'Title', body: 'Body');

      final wire = settings.toWire();

      expect(wire.iconColorAlpha, isNull);
      expect(wire.iconColorRed, isNull);
      expect(wire.iconColorGreen, isNull);
      expect(wire.iconColorBlue, isNull);
    });
  });

  group('NotificationSettings snooze copyWith', () {
    test('androidSnoozeButton can be set and cleared through the callback', () {
      const settings = NotificationSettings(
        title: 'Title',
        body: 'Body',
        androidSnoozeButton: 'Snooze',
      );

      expect(settings.copyWith().androidSnoozeButton, 'Snooze');
      expect(
        settings
            .copyWith(androidSnoozeButton: () => 'Later')
            .androidSnoozeButton,
        'Later',
      );
      expect(
        settings.copyWith(androidSnoozeButton: () => null).androidSnoozeButton,
        isNull,
      );
    });
  });

  group('NotificationSettings copyWith', () {
    test('replaces only the provided fields', () {
      const settings = NotificationSettings(
        title: 'Title',
        body: 'Body',
        stopButton: 'Stop',
      );

      final copy = settings.copyWith(title: 'New title');

      expect(copy.title, 'New title');
      expect(copy.body, 'Body');
      expect(copy.stopButton, 'Stop');
      expect(copy.androidStopAlarmOnDismiss, isTrue);
    });

    test('can turn androidStopAlarmOnDismiss off', () {
      const settings = NotificationSettings(title: 'Title', body: 'Body');

      expect(
        settings
            .copyWith(androidStopAlarmOnDismiss: false)
            .androidStopAlarmOnDismiss,
        isFalse,
      );
    });
  });
}
