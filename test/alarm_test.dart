import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/service/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm', () {
    setUp(() async {
      const channel =
          MethodChannel('dexterous.com/flutter/local_notifications');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize') {
          return true;
        }
        if (call.method == 'zonedSchedule') {
          return true;
        }
        return null;
      });

      const MethodChannel('plugins.flutter.io/shared_preferences')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getAll':
            return <String, dynamic>{};
          case 'commit':
          case 'remove':
          case 'setBool':
          case 'setDouble':
          case 'setInt':
          case 'setString':
          case 'setStringList':
            return true;
          default:
            return null;
        }
      });

      const MethodChannel(
        'dev.fluttercommunity.plus/android_alarm_manager',
        JSONMethodCodec(),
      ).setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'Alarm.oneShotAt') {
          return true;
        }
        return null;
      });

      const MethodChannel('com.gdelataillade.alarm/notifOnAppKill')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'setNotificationOnKillService') {
          return true;
        }
        return null;
      });

      await Alarm.init();
    });

    test('basic alarm flow', () async {
      final alarmSettings = AlarmSettings(
        id: 42,
        dateTime: DateTime.now().add(const Duration(seconds: 5)),
        assetAudioPath: 'example/assets/alarm.mp3',
        enableNotificationOnKill: false,
      );

      final res = await Alarm.set(alarmSettings: alarmSettings);
      expect(res, isTrue);

      final alarms = AlarmStorage.getSavedAlarms();

      final alarm = alarms.firstWhere(
        (alarm) => alarm.id == alarmSettings.id,
        orElse: () => fail('Alarm not found'),
      );

      expect(alarm == alarmSettings, true);

      // TODO: Stop alarm
    });
  });
}
