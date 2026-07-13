import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AlarmSettings buildAlarm(int id, {DateTime? dateTime}) {
    return AlarmSettings(
      id: id,
      dateTime: dateTime ?? DateTime(2030),
      volumeSettings: const VolumeSettings.fixed(),
      notificationSettings: const NotificationSettings(
        title: 'Title',
        body: 'Body',
      ),
    );
  }

  group('AlarmSet', () {
    test('empty set contains nothing', () {
      final set = AlarmSet.empty();

      expect(set.alarms, isEmpty);
      expect(set.containsId(1), isFalse);
    });

    test('add returns a new set containing the alarm', () {
      final set = AlarmSet.empty();
      final alarm = buildAlarm(1);

      final updated = set.add(alarm);

      expect(updated.contains(alarm), isTrue);
      expect(updated.containsId(1), isTrue);
      // The original set is unchanged.
      expect(set.alarms, isEmpty);
    });

    test('add is a no-op for an alarm with an existing id', () {
      final alarm = buildAlarm(1);
      final set = AlarmSet.empty().add(alarm);

      final updated = set.add(buildAlarm(1, dateTime: DateTime(2031)));

      expect(identical(updated, set), isTrue);
      expect(updated.alarms, hasLength(1));
    });

    test('remove drops the alarm by id', () {
      final alarm = buildAlarm(1);
      final set = AlarmSet.empty().add(alarm).add(buildAlarm(2));

      final updated = set.remove(alarm);

      expect(updated.containsId(1), isFalse);
      expect(updated.containsId(2), isTrue);
    });

    test('remove is a no-op when the alarm is absent', () {
      final set = AlarmSet.empty().add(buildAlarm(1));

      final updated = set.remove(buildAlarm(2));

      expect(identical(updated, set), isTrue);
    });

    test('removeById drops the alarm', () {
      final set = AlarmSet.empty().add(buildAlarm(1)).add(buildAlarm(2));

      final updated = set.removeById(1);

      expect(updated.containsId(1), isFalse);
      expect(updated.containsId(2), isTrue);
    });

    test('removeById is a no-op when the id is absent', () {
      final set = AlarmSet.empty().add(buildAlarm(1));

      final updated = set.removeById(42);

      expect(identical(updated, set), isTrue);
    });

    test('sets with the same alarms compare equal', () {
      final a = AlarmSet([buildAlarm(1), buildAlarm(2)]);
      final b = AlarmSet([buildAlarm(1), buildAlarm(2)]);

      expect(a, equals(b));
    });
  });
}
