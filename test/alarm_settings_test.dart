import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AlarmSettings buildSettings({
    int id = 1,
    DateTime? dateTime,
    String? assetAudioPath = 'assets/alarm.mp3',
    String? payload,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: dateTime ?? DateTime(2030, 1, 2, 3, 4, 5),
      assetAudioPath: assetAudioPath,
      volumeSettings: VolumeSettings.fade(
        volume: 0.8,
        fadeDuration: const Duration(seconds: 5),
      ),
      notificationSettings: const NotificationSettings(
        title: 'Title',
        body: 'Body',
        stopButton: 'Stop',
      ),
      payload: payload,
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
  });

  group('AlarmSettings equality', () {
    test('equal settings compare equal', () {
      expect(buildSettings(), equals(buildSettings()));
    });

    test('different ids compare unequal', () {
      expect(buildSettings(), isNot(equals(buildSettings(id: 2))));
    });
  });
}
