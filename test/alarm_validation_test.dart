import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AlarmSettings buildSettings(int id) {
    return AlarmSettings(
      id: id,
      dateTime: DateTime(2030),
      volumeSettings: const VolumeSettings.fixed(),
      notificationSettings: const NotificationSettings(
        title: 'Title',
        body: 'Body',
      ),
    );
  }

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
