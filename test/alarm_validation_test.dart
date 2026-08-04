import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  AlarmSettings buildSettings(
    int id, {
    Duration? snoozeDuration,
    String? snoozeButton,
    String? stopButton,
    bool stopAlarmOnDismiss = true,
  }) {
    return AlarmSettings(
      id: id,
      dateTime: DateTime(2030),
      volumeSettings: const VolumeSettings.fixed(),
      androidSnoozeDuration: snoozeDuration,
      notificationSettings: NotificationSettings(
        title: 'Title',
        body: 'Body',
        stopButton: stopButton,
        androidSnoozeButton: snoozeButton,
        androidStopAlarmOnDismiss: stopAlarmOnDismiss,
      ),
    );
  }

  List<LogRecord> captureLogs() {
    final records = <LogRecord>[];
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    return records;
  }

  Iterable<LogRecord> dismissWarnings(List<LogRecord> records) =>
      records.where((r) => r.message.contains('androidStopAlarmOnDismiss'));

  group('Alarm.alarmSettingsValidation', () {
    test('accepts a regular id', () {
      expect(
        () => Alarm.alarmSettingsValidation(buildSettings(42)),
        returnsNormally,
      );
    });

    test('accepts negative ids other than -1', () {
      expect(
        () => Alarm.alarmSettingsValidation(buildSettings(-42)),
        returnsNormally,
      );
    });

    test('rejects id 0', () {
      expect(
        () => Alarm.alarmSettingsValidation(buildSettings(0)),
        throwsA(isA<AlarmException>()),
      );
    });

    test('rejects id -1', () {
      expect(
        () => Alarm.alarmSettingsValidation(buildSettings(-1)),
        throwsA(isA<AlarmException>()),
      );
    });

    test('rejects ids beyond the 32-bit integer range', () {
      expect(
        () => Alarm.alarmSettingsValidation(buildSettings(2147483648)),
        throwsA(isA<AlarmException>()),
      );
      expect(
        () => Alarm.alarmSettingsValidation(buildSettings(-2147483649)),
        throwsA(isA<AlarmException>()),
      );
    });

    test('rejects a non-positive snooze duration', () {
      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(42, snoozeDuration: Duration.zero),
        ),
        throwsA(isA<AlarmException>()),
      );
      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(42, snoozeDuration: const Duration(seconds: -1)),
        ),
        throwsA(isA<AlarmException>()),
      );
    });

    test('accepts a snooze duration at the minimum', () {
      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(
            42,
            snoozeDuration: AlarmSettings.minSnoozeDuration,
            snoozeButton: 'Snooze',
          ),
        ),
        returnsNormally,
      );
    });

    test('only warns for a snooze below the minimum', () {
      // Inert on iOS and gated natively, so a too-short duration degrades to
      // no snooze rather than failing the whole alarm.
      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(
            42,
            snoozeDuration: const Duration(seconds: 5),
            snoozeButton: 'Snooze',
          ),
        ),
        returnsNormally,
      );
    });

    test('only warns when the label and duration do not agree', () {
      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(42, snoozeButton: 'Snooze'),
        ),
        returnsNormally,
      );
      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(42, snoozeDuration: const Duration(minutes: 9)),
        ),
        returnsNormally,
      );
    });

    test('warns when a dismiss-proof notification offers no stop button', () {
      // Both together leave the notification with no stop affordance at all:
      // no action button, and no delete intent behind the swipe.
      final records = captureLogs();

      expect(
        () => Alarm.alarmSettingsValidation(
          buildSettings(42, stopAlarmOnDismiss: false),
        ),
        returnsNormally,
      );
      expect(dismissWarnings(records), hasLength(1));
    });

    test('does not warn when a dismiss-proof alarm has a stop button', () {
      final records = captureLogs();

      Alarm.alarmSettingsValidation(
        buildSettings(42, stopButton: 'Stop', stopAlarmOnDismiss: false),
      );
      Alarm.alarmSettingsValidation(buildSettings(43));

      expect(dismissWarnings(records), isEmpty);
    });
  });

  group('AlarmException', () {
    test('toString contains the code and message', () {
      const exception = AlarmException(
        AlarmErrorCode.invalidArguments,
        message: 'Bad id',
      );

      expect(exception.toString(), contains('invalidArguments'));
      expect(exception.toString(), contains('Bad id'));
    });
  });
}
