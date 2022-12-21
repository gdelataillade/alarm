import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alarm/alarm_method_channel.dart';

void main() {
  MethodChannelAlarm platform = MethodChannelAlarm();
  const MethodChannel channel = MethodChannel('alarm');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
