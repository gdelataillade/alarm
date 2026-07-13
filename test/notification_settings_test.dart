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
        icon: 'notification_icon',
        iconColor: Color(0xFF862778),
        keepNotificationAfterAlarmEnds: true,
      );

      final restored = NotificationSettings.fromJson(settings.toJson());

      expect(restored, equals(settings));
    });

    test('round trips with optional fields absent', () {
      const settings = NotificationSettings(title: 'Title', body: 'Body');

      final restored = NotificationSettings.fromJson(settings.toJson());

      expect(restored.stopButton, isNull);
      expect(restored.icon, isNull);
      expect(restored.iconColor, isNull);
      expect(restored.keepNotificationAfterAlarmEnds, isFalse);
      expect(restored, equals(settings));
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

    test('leaves color channels null when no color is set', () {
      const settings = NotificationSettings(title: 'Title', body: 'Body');

      final wire = settings.toWire();

      expect(wire.iconColorAlpha, isNull);
      expect(wire.iconColorRed, isNull);
      expect(wire.iconColorGreen, isNull);
      expect(wire.iconColorBlue, isNull);
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
    });
  });
}
