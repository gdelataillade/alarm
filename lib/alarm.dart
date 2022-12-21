
import 'alarm_platform_interface.dart';

class Alarm {
  Future<String?> getPlatformVersion() {
    return AlarmPlatform.instance.getPlatformVersion();
  }
}
