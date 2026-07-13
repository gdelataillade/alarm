import 'package:alarm/alarm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VolumeSettings constructors', () {
    test('fixed keeps the provided volume', () {
      const settings = VolumeSettings.fixed(volume: 0.4);

      expect(settings.volume, 0.4);
      expect(settings.fadeDuration, isNull);
      expect(settings.fadeSteps, isEmpty);
    });

    test('fade keeps the provided duration', () {
      final settings = VolumeSettings.fade(
        fadeDuration: const Duration(seconds: 10),
      );

      expect(settings.fadeDuration, const Duration(seconds: 10));
    });

    test('staircaseFade keeps the provided steps', () {
      final settings = VolumeSettings.staircaseFade(
        fadeSteps: [
          VolumeFadeStep(Duration.zero, 0),
          VolumeFadeStep(const Duration(seconds: 10), 0.5),
          VolumeFadeStep(const Duration(seconds: 20), 1),
        ],
      );

      expect(settings.fadeSteps, hasLength(3));
    });

    test('rejects out-of-range volume', () {
      expect(
        () => VolumeSettings.fixed(volume: 1.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VolumeSettings.fixed(volume: -0.1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects non-positive fade duration', () {
      expect(
        () => VolumeSettings.fade(fadeDuration: Duration.zero),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects empty fade steps', () {
      expect(
        () => VolumeSettings.staircaseFade(fadeSteps: const []),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects unsorted fade steps', () {
      expect(
        () => VolumeSettings.staircaseFade(
          fadeSteps: [
            VolumeFadeStep(const Duration(seconds: 10), 0.5),
            VolumeFadeStep(Duration.zero, 0),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects negative fade step time and out-of-range volume', () {
      expect(
        () => VolumeFadeStep(const Duration(seconds: -1), 0.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VolumeFadeStep(Duration.zero, 1.5),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('VolumeSettings JSON', () {
    test('round trips fade settings', () {
      final settings = VolumeSettings.fade(
        volume: 0.7,
        fadeDuration: const Duration(milliseconds: 2500),
        volumeEnforced: true,
        showSystemUI: false,
      );

      final restored = VolumeSettings.fromJson(settings.toJson());

      expect(restored, equals(settings));
    });

    test('round trips staircase settings', () {
      final settings = VolumeSettings.staircaseFade(
        fadeSteps: [
          VolumeFadeStep(Duration.zero, 0),
          VolumeFadeStep(const Duration(seconds: 15), 1),
        ],
      );

      final restored = VolumeSettings.fromJson(settings.toJson());

      expect(restored, equals(settings));
    });

    test('defaults showSystemUI to true when absent', () {
      const settings = VolumeSettings.fixed(volume: 0.4);
      final json = settings.toJson()..remove('showSystemUI');

      final restored = VolumeSettings.fromJson(json);

      expect(restored.showSystemUI, isTrue);
    });
  });

  group('VolumeSettings toWire', () {
    test('converts durations to milliseconds', () {
      final settings = VolumeSettings.staircaseFade(
        volume: 0.9,
        fadeSteps: [
          VolumeFadeStep(Duration.zero, 0),
          VolumeFadeStep(const Duration(milliseconds: 1500), 1),
        ],
      );

      final wire = settings.toWire();

      expect(wire.volume, 0.9);
      expect(wire.fadeDurationMillis, isNull);
      expect(wire.fadeSteps, hasLength(2));
      expect(wire.fadeSteps[1].timeMillis, 1500);
      expect(wire.fadeSteps[1].volume, 1);
    });
  });
}
