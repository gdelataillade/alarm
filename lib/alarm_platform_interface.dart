import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'alarm_method_channel.dart';

abstract class AlarmPlatform extends PlatformInterface {
  /// Constructs a AlarmPlatform.
  AlarmPlatform() : super(token: _token);

  static final Object _token = Object();

  static AlarmPlatform _instance = MethodChannelAlarm();

  /// The default instance of [AlarmPlatform] to use.
  ///
  /// Defaults to [MethodChannelAlarm].
  static AlarmPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AlarmPlatform] when
  /// they register themselves.
  static set instance(AlarmPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
