import 'package:flutter_test/flutter_test.dart';
import 'package:alarm/alarm.dart';
import 'package:alarm/alarm_platform_interface.dart';
import 'package:alarm/alarm_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAlarmPlatform
    with MockPlatformInterfaceMixin
    implements AlarmPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AlarmPlatform initialPlatform = AlarmPlatform.instance;

  test('$MethodChannelAlarm is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAlarm>());
  });

  test('getPlatformVersion', () async {
    Alarm alarmPlugin = Alarm();
    MockAlarmPlatform fakePlatform = MockAlarmPlatform();
    AlarmPlatform.instance = fakePlatform;

    expect(await alarmPlugin.getPlatformVersion(), '42');
  });
}
