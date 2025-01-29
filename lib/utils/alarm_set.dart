import 'dart:collection';

import 'package:alarm/model/alarm_settings.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

/// A set of alarms where uniqueness is determined by the [AlarmSettings.id].
class AlarmSet extends Equatable {
  /// Constructs an instance of [AlarmSet] using the given [alarms].
  AlarmSet(Iterable<AlarmSettings> alarms)
      : _alarms = UnmodifiableSetView(
          HashSet<AlarmSettings>(
            equals: (a, b) => a.id == b.id,
            hashCode: (a) => a.id.hashCode,
          )..addAll(alarms),
        );

  /// Empty [AlarmSet].
  AlarmSet.empty() : _alarms = UnmodifiableSetView(const {});

  final UnmodifiableSetView<AlarmSettings> _alarms;

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
    return AlarmSet(Set.from(_alarms)..add(alarm));
  }

  /// Returns a new [AlarmSet] with the given [alarm] removed.
  AlarmSet remove(AlarmSettings alarm) {
    if (!_alarms.contains(alarm)) {
      return this;
    }
    return AlarmSet(Set.from(_alarms)..remove(alarm));
  }

  /// Returns a new [AlarmSet] with the given [alarmId] removed.
  AlarmSet removeById(int alarmId) {
    final alarm = _alarms.firstWhereOrNull((a) => a.id == alarmId);
    if (alarm == null) return this;
    return remove(alarm);
  }

  @override
  List<Object?> get props => [_alarms];
}
