import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AlarmSettings buildSettings({
    int id = 1,
    DateTime? dateTime,
    String? assetAudioPath = 'assets/alarm.mp3',
    String? payload,
    Duration? snoozeDuration,
    String? snoozeButton,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: dateTime ?? DateTime(2030, 1, 2, 3, 4, 5),
      assetAudioPath: assetAudioPath,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
      ),
      notificationSettings: NotificationSettings(
        title: 'Title',
        body: 'Body',
        stopButton: 'Stop',
        androidSnoozeButton: snoozeButton,
      ),
      payload: payload,
      androidSnoozeDuration: snoozeDuration,
    );
  }

  group('AlarmSettings JSON', () {
    test('round trips through toJson/fromJson', () {
      final settings = buildSettings(payload: 'some payload');

      final restored = AlarmSettings.fromJson(settings.toJson());

      expect(restored, equals(settings));
    });

    test('round trips with null assetAudioPath and payload', () {
      final settings = buildSettings(assetAudioPath: null);

      final restored = AlarmSettings.fromJson(settings.toJson());

      expect(restored.assetAudioPath, isNull);
      expect(restored.payload, isNull);
      expect(restored, equals(settings));
    });

    test('defaults optional flags when absent', () {
      final json = buildSettings().toJson()
        ..remove('allowAlarmOverlap')
        ..remove('allowSameSecondScheduling')
        ..remove('androidStopAlarmOnTermination')
        ..remove('preferConnectedAudioDevice')
        ..remove('iOSBackgroundAudio');

      final restored = AlarmSettings.fromJson(json);

      expect(restored.allowAlarmOverlap, isFalse);
      expect(restored.allowSameSecondScheduling, isFalse);
      expect(restored.androidStopAlarmOnTermination, isTrue);
      expect(restored.preferConnectedAudioDevice, isFalse);
      expect(restored.iOSBackgroundAudio, isTrue);
    });
  });

  group('AlarmSettings v4 backward compatibility', () {
    Map<String, dynamic> v4Json({Object? dateTime}) {
      return <String, dynamic>{
        'id': 7,
        'dateTime':
            dateTime ?? DateTime(2030, 1, 2, 3, 4, 5).microsecondsSinceEpoch,
        'assetAudioPath': 'assets/alarm.mp3',
        'loopAudio': true,
        'vibrate': true,
        'volume': 0.5,
        'fadeDuration': 3.0,
        'volumeEnforced': true,
        'warningNotificationOnKill': true,
        'androidFullScreenIntent': true,
        'notificationSettings': const NotificationSettings(
          title: 'Title',
          body: 'Body',
        ).toJson(),
      };
    }

    test('parses v4 JSON with dateTime in microseconds', () {
      final restored = AlarmSettings.fromJson(v4Json());

      expect(restored.id, 7);
      expect(restored.dateTime, DateTime(2030, 1, 2, 3, 4, 5));
    });

    test('parses v4 JSON with dateTime as ISO-8601 string', () {
      final restored = AlarmSettings.fromJson(
        v4Json(dateTime: DateTime(2030, 1, 2, 3, 4, 5).toIso8601String()),
      );

      expect(restored.dateTime, DateTime(2030, 1, 2, 3, 4, 5));
    });

    test('converts v4 volume fields into VolumeSettings', () {
      final restored = AlarmSettings.fromJson(v4Json());

      expect(restored.volumeSettings.volume, 0.5);
      // v4 stored fadeDuration in (fractional) seconds.
      expect(restored.volumeSettings.fadeDuration, const Duration(seconds: 3));
      expect(restored.volumeSettings.volumeEnforced, isTrue);
      expect(restored.volumeSettings.fadeSteps, isEmpty);
    });

    test('applies v4 defaults for fields introduced in v5', () {
      final restored = AlarmSettings.fromJson(v4Json());

      expect(restored.allowAlarmOverlap, isFalse);
      expect(restored.allowSameSecondScheduling, isFalse);
      expect(restored.iOSBackgroundAudio, isTrue);
    });

    test('throws when dateTime is missing', () {
      final json = v4Json()..remove('dateTime');

      expect(() => AlarmSettings.fromJson(json), throwsArgumentError);
    });
  });

  group('AlarmSettings toWire', () {
    test('maps fields to the wire format', () {
      final settings = buildSettings();

      final wire = settings.toWire();

      expect(wire.id, settings.id);
      expect(
        wire.millisecondsSinceEpoch,
        settings.dateTime.millisecondsSinceEpoch,
      );
      expect(wire.assetAudioPath, settings.assetAudioPath);
      expect(wire.loopAudio, settings.loopAudio);
      expect(
        wire.volumeSettings.fadeDurationMillis,
        settings.volumeSettings.fadeDuration!.inMilliseconds,
      );
      expect(wire.notificationSettings.title, 'Title');
    });

    test('sends the snooze duration in milliseconds', () {
      final settings = buildSettings(
        snoozeDuration: const Duration(minutes: 9),
        snoozeButton: 'Snooze',
      );

      final wire = settings.toWire();

      expect(wire.androidSnoozeDurationMillis, 9 * 60 * 1000);
      expect(wire.notificationSettings.androidSnoozeButton, 'Snooze');
    });

    test('leaves the snooze fields null when no snooze is configured', () {
      final wire = buildSettings().toWire();

      expect(wire.androidSnoozeDurationMillis, isNull);
      expect(wire.notificationSettings.androidSnoozeButton, isNull);
    });
  });

  group('AlarmSettings copyWith', () {
    test('replaces only the provided fields', () {
      final settings = buildSettings();

      final copy = settings.copyWith(id: 2, loopAudio: false);

      expect(copy.id, 2);
      expect(copy.loopAudio, isFalse);
      expect(copy.dateTime, settings.dateTime);
      expect(copy.notificationSettings, settings.notificationSettings);
    });

    test('payload can be set and cleared through the callback', () {
      final settings = buildSettings(payload: 'original');

      expect(settings.copyWith().payload, 'original');
      expect(settings.copyWith(payload: () => 'new').payload, 'new');
      expect(settings.copyWith(payload: () => null).payload, isNull);
    });

    test('androidSnoozeDuration can be set and cleared through the callback',
        () {
      final settings = buildSettings(
        snoozeDuration: const Duration(minutes: 9),
        snoozeButton: 'Snooze',
      );

      expect(
        settings.copyWith().androidSnoozeDuration,
        const Duration(minutes: 9),
      );
      expect(
        settings
            .copyWith(
              androidSnoozeDuration: () => const Duration(minutes: 5),
            )
            .androidSnoozeDuration,
        const Duration(minutes: 5),
      );
      expect(
        settings
            .copyWith(androidSnoozeDuration: () => null)
            .androidSnoozeDuration,
        isNull,
      );
    });
  });

  group('AlarmSettings snooze JSON', () {
    test('round trips the snooze duration and label', () {
      final settings = buildSettings(
        snoozeDuration: const Duration(minutes: 9),
        snoozeButton: 'Snooze',
      );

      final restored = AlarmSettings.fromJson(settings.toJson());

      expect(restored.androidSnoozeDuration, const Duration(minutes: 9));
      expect(
        restored.notificationSettings.androidSnoozeButton,
        'Snooze',
      );
      expect(restored, equals(settings));
    });

    test('parses alarms stored before snooze existed', () {
      final json = buildSettings().toJson()..remove('androidSnoozeDuration');
      (json['notificationSettings']! as Map<String, dynamic>)
          .remove('androidSnoozeButton');

      final restored = AlarmSettings.fromJson(json);

      expect(restored.androidSnoozeDuration, isNull);
      expect(restored.notificationSettings.androidSnoozeButton, isNull);
    });
  });

  group('AlarmSettings equality', () {
    test('equal settings compare equal', () {
      expect(buildSettings(), equals(buildSettings()));
    });

    test('different ids compare unequal', () {
      expect(buildSettings(), isNot(equals(buildSettings(id: 2))));
    });
  });

  group('AlarmSettings androidStaleAfter', () {
    // Three states have to survive storage, and a plain nullable field cannot
    // express them: json_serializable omits a null from the encoded map, and
    // reads a missing key as the constructor default. That would turn "never
    // discard" into fifteen minutes on the first restart after it was set,
    // which is the one moment the choice matters.
    Map<String, dynamic> encoded(AlarmSettings settings) =>
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>;

    test('defaults to fifteen minutes when the caller says nothing', () {
      expect(AlarmSettings.defaultStaleAfter, const Duration(minutes: 15));
      expect(
        buildSettings().androidStaleAfter,
        AlarmSettings.defaultStaleAfter,
      );
    });

    test('an explicit null survives a round trip as never discard', () {
      final json =
          encoded(buildSettings().copyWith(androidStaleAfter: () => null));

      expect(json['androidStaleAfter'], AlarmSettings.neverDiscardSentinel);
      expect(AlarmSettings.fromJson(json).androidStaleAfter, isNull);
    });

    test('a duration survives a round trip', () {
      final json = encoded(
        buildSettings().copyWith(
          androidStaleAfter: () => const Duration(minutes: 40),
        ),
      );

      expect(
        AlarmSettings.fromJson(json).androidStaleAfter,
        const Duration(minutes: 40),
      );
    });

    test('an alarm stored before the setting existed takes the default', () {
      final json = encoded(buildSettings())..remove('androidStaleAfter');

      expect(
        AlarmSettings.fromJson(json).androidStaleAfter,
        AlarmSettings.defaultStaleAfter,
      );
    });

    test('an integral double is read as that duration', () {
      final json = buildSettings().toJson()
        ..['androidStaleAfter'] =
            const Duration(minutes: 20).inMicroseconds * 1.0;

      expect(
        AlarmSettings.fromJson(json).androidStaleAfter,
        const Duration(minutes: 20),
      );
    });

    test('an unusable value falls back to the default rather than throwing',
        () {
      // Throwing would be worse than wrong: nothing between Alarm.init and the
      // storage read catches, so one malformed field would cost the user every
      // stored alarm. A fraction is in the list because 1.5 microseconds would
      // otherwise truncate to a one-microsecond window and discard everything.
      for (final unusable in <Object?>[
        'oops',
        1.5,
        -2,
        double.nan,
        double.infinity,
        <int>[],
        <String, int>{},
      ]) {
        final json = buildSettings().toJson()..['androidStaleAfter'] = unusable;

        expect(
          AlarmSettings.fromJson(json).androidStaleAfter,
          AlarmSettings.defaultStaleAfter,
          reason: 'for $unusable',
        );
      }
    });

    test('toWire sends milliseconds, and null for never discard', () {
      expect(buildSettings().toWire().androidStaleAfterMillis, 900000);
      expect(
        buildSettings()
            .copyWith(androidStaleAfter: () => null)
            .toWire()
            .androidStaleAfterMillis,
        isNull,
      );
    });

    test('copyWith can clear it and set it back', () {
      final never = buildSettings().copyWith(androidStaleAfter: () => null);
      expect(never.androidStaleAfter, isNull);

      final restored =
          never.copyWith(androidStaleAfter: () => const Duration(hours: 1));
      expect(restored.androidStaleAfter, const Duration(hours: 1));

      // Not passing it at all leaves the choice alone, including the null one.
      expect(never.copyWith(id: 9).androidStaleAfter, isNull);
    });
  });

  group('AlarmSettings androidAlarmClock', () {
    test('defaults to true, including for alarms stored before it existed', () {
      expect(buildSettings().androidAlarmClock, isTrue);

      final legacy = buildSettings().toJson()..remove('androidAlarmClock');
      expect(AlarmSettings.fromJson(legacy).androidAlarmClock, isTrue);
    });

    test('an opt-out survives a round trip and reaches the wire', () {
      final optOut = buildSettings().copyWith(androidAlarmClock: false);
      final restored = AlarmSettings.fromJson(
        jsonDecode(jsonEncode(optOut.toJson())) as Map<String, dynamic>,
      );

      expect(restored.androidAlarmClock, isFalse);
      expect(optOut.toWire().androidAlarmClock, isFalse);
      expect(optOut, isNot(buildSettings()));
    });
  });
}
