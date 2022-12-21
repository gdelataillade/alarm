import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'alarm_platform_interface.dart';

/// An implementation of [AlarmPlatform] that uses method channels.
class MethodChannelAlarm extends AlarmPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('alarm');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
