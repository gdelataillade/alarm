import 'package:alarm/alarm.dart';
import 'package:alarm/service/alarm_storage.dart';
import 'package:alarm/src/alarm_trigger_api_impl.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_host.dart';

/// Reconciliation and set-failure behaviour, both about the plugin not lying
/// about an alarm's state.
///
/// The two regressions here are the worst shape a failure can take in an alarm
/// app, because nothing reports them: an alarm that was about to ring being
/// cancelled by a startup pass, and a host that could not arm an alarm being
/// reported as success.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHost host;

  AlarmSettings buildAlarm(int id, DateTime dateTime) => AlarmSettings(
        id: id,
        dateTime: dateTime,
        volumeSettings: const VolumeSettings.fixed(),
        notificationSettings: const NotificationSettings(
          title: 'Wake up',
          body: '',
        ),
      );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Alarm.resetForTesting();
    AlarmStorage.resetForTesting();
    AlarmTriggerApiImpl.resetForTesting();
    host = FakeHost()..install();
  });

  tearDown(() {
    host.remove();
    Alarm.resetForTesting();
    AlarmStorage.resetForTesting();
    AlarmTriggerApiImpl.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  group('checkAlarm ring-start grace', () {
    test('an alarm that came due moments ago is left alone', () async {
      // The alarm is due but the host does not report it as ringing yet, which
      // is what the whole delivery chain looks like from Dart: broadcast, maybe
      // a process start, foreground service, player prepare. Stopping here
      // cancels a ring that is on its way.
      await AlarmStorage.saveAlarm(
        buildAlarm(42, DateTime.now().subtract(const Duration(seconds: 2))),
      );

      await Alarm.init();

      expect(
        host.calls,
        isNot(contains('stopAlarm')),
        reason: 'an alarm that is about to sound must not be cancelled',
      );
      expect(
        await Alarm.getAlarm(42),
        isNotNull,
        reason: 'and it must stay stored so the ring can still be reported',
      );
    });

    test('an alarm long past due is still stopped', () async {
      await AlarmStorage.saveAlarm(
        buildAlarm(42, DateTime.now().subtract(const Duration(minutes: 2))),
      );

      await Alarm.init();

      expect(host.calls, contains('stopAlarm'));
      expect(await Alarm.getAlarms(), isEmpty);
    });

    test('an alarm the host reports as ringing is marked ringing, not spared',
        () async {
      // Guards that the grace window did not shadow the branch above it: a host
      // that says "ringing" must still put the alarm on the ringing stream.
      final alarm =
          buildAlarm(42, DateTime.now().subtract(const Duration(seconds: 2)));
      await AlarmStorage.saveAlarm(alarm);
      host.ringing.add(42);

      await Alarm.init();

      expect(Alarm.ringing.value.containsId(42), isTrue);
      expect(host.calls, isNot(contains('stopAlarm')));
    });

    test('an old alarm queued behind another ring is left scheduled', () async {
      await AlarmStorage.saveAlarm(
        buildAlarm(42, DateTime.now().subtract(const Duration(minutes: 2))),
      );
      host.queued.add(42);

      await Alarm.init();

      expect(host.calls, isNot(contains('stopAlarm')));
      expect(await Alarm.getAlarm(42), isNotNull);
      expect(Alarm.ringing.value.containsId(42), isFalse);
    });

    test('iOS still stops a past-due alarm', () async {
      // Asserts preserved behaviour rather than isolating the Android gate:
      // iOS runs stopAll() before the loop, which empties storage, so the
      // re-read finds nothing and the grace window is unreachable either way.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await AlarmStorage.saveAlarm(
        buildAlarm(42, DateTime.now().subtract(const Duration(seconds: 2))),
      );

      await Alarm.init();

      expect(host.calls, contains('stopAll'));
      expect(host.calls, contains('stopAlarm'));
      expect(await Alarm.getAlarms(), isEmpty);
    });
  });

  group('set() when the host cannot arm the alarm', () {
    test('reports the failure and leaves nothing behind', () async {
      // The host stores the alarm before arming it, so a failure it reported as
      // success left a phantom: set() returned true, getAlarms() kept listing
      // the alarm, and nothing ever rang.
      host.setAlarmError = (
        code: AlarmErrorCode.pluginInternal.index.toString(),
        message: 'Alarm 42 could not be armed.',
      );

      await expectLater(
        Alarm.set(
          alarmSettings:
              buildAlarm(42, DateTime.now().add(const Duration(hours: 1))),
        ),
        throwsA(
          isA<AlarmException>()
              .having((e) => e.code, 'code', AlarmErrorCode.pluginInternal),
        ),
      );

      expect(host.calls, contains('setAlarm'));
      expect(
        host.calls,
        contains('stopAlarm'),
        reason: 'the failed alarm has to be torn down, not left half-created',
      );
      expect(await Alarm.getAlarms(), isEmpty);
      expect(Alarm.scheduled.value.alarms, isEmpty);
    });
  });
}
