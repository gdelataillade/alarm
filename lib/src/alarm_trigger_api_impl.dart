import 'package:alarm/alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:logging/logging.dart';

/// Implements the API that handles calls coming from the host platform.
class AlarmTriggerApiImpl extends AlarmTriggerApi {
  AlarmTriggerApiImpl._() {
    AlarmTriggerApi.setUp(this);
  }

  static final _log = Logger('AlarmTriggerApiImpl');

  /// Cached instance of [AlarmTriggerApiImpl]
  static AlarmTriggerApiImpl? _instance;

  /// Ensures that this Dart isolate is listening for method calls that may come
  /// from the host platform.
  static void ensureInitialized() {
    _instance ??= AlarmTriggerApiImpl._();
  }

  @override
  Future<void> alarmRang(int alarmId) async {
    final settings = await Alarm.getAlarm(alarmId);
    if (settings == null) {
      _log.severe('Alarm with id $alarmId started ringing but the settings '
          'object could not be found. Please report this issue at: '
          'https://github.com/gdelataillade/alarm/issues');
      return;
    }
    Alarm.ringStream.add(settings);
  }

  @override
  Future<void> alarmStopped(int alarmId) async {
    await Alarm.reload(alarmId);
  }
}
