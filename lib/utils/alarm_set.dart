import 'dart:collection';

import 'package:alarm/model/alarm_settings.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

/// A set of alarms where uniqueness is determined by the [AlarmSettings.id].
class AlarmSet extends Equatable {
  /// Constructs an instance of [AlarmSet] using the given [alarms].
  AlarmSet(Iterable<AlarmSettings> alarms) : _alarms = _idSet()..addAll(alarms);

  /// Empty [AlarmSet].
  AlarmSet.empty() : _alarms = _idSet();

  static HashSet<AlarmSettings> _idSet() => HashSet<AlarmSettings>(
        equals: (a, b) => a.id == b.id,
        hashCode: (a) => a.id.hashCode,
      );

  final HashSet<AlarmSettings> _alarms;

  /// Returns the set of alarms.
  Set<AlarmSettings> get alarms => _alarms;

  /// Returns `true` if the set contains the given [alarm].
  bool contains(AlarmSettings alarm) => _alarms.contains(alarm);

  /// Returns `true` if the set contains an alarm with the given [alarmId].
  bool containsId(int alarmId) => _alarms.any((a) => a.id == alarmId);

  /// Returns a new [AlarmSet] with the given [alarm] added.
  AlarmSet add(AlarmSettings alarm) {
    if (_alarms.contains(alarm)) {
      return this;
    }
    return AlarmSet([..._alarms, alarm]);
  }

  /// Returns a new [AlarmSet] with the given [alarm] removed.
  AlarmSet remove(AlarmSettings alarm) {
    if (!_alarms.contains(alarm)) {
      return this;
    }
    return AlarmSet(_alarms.where((a) => a.id != alarm.id));
  }

  /// Returns a new [AlarmSet] with the given [alarmId] removed.
  AlarmSet removeById(int alarmId) {
    if (_alarms.none((alarm) => alarm.id == alarmId)) return this;
    return AlarmSet(_alarms.where((a) => a.id != alarmId));
  }

  @override
  List<Object?> get props => [_alarms];
}
