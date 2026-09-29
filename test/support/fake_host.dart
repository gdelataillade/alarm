import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the Android host over the real pigeon channels.
///
/// Several of the contracts worth testing are negotiations between Dart and the
/// host rather than pure Dart logic — the host records a snooze marker and Dart
/// applies it, or the host refuses to arm an alarm and Dart has to undo its own
/// bookkeeping — so the interesting behaviour only shows up when both halves
/// are present. Recording every call also lets a test assert what Dart did
/// *not* do, which is what the reconciliation regressions are about.
class FakeHost {
  FakeHost();

  final List<String> calls = <String>[];
  final List<AlarmEventWire> pending = <AlarmEventWire>[];
  final List<(int, int)> acknowledged = <(int, int)>[];
  final Set<int> ringing = <int>{};
  final Set<int> queued = <int>{};

  /// When set, `setAlarm` replies with this error instead of succeeding.
  ///
  /// A three-element reply is pigeon's error envelope, which the generated Dart
  /// client turns into a `PlatformException`. That is the only way to reach the
  /// Dart side of a host that stored an alarm but could not arm it. Use the raw
  /// `AlarmErrorCode` index as the code, the way the host does.
  ({String code, String message})? setAlarmError;

  static const _prefix = 'dev.flutter.pigeon.alarm.AlarmApi.';

  static const _methods = <String>[
    'getPendingAlarmEvents',
    'acknowledgeAlarmEvent',
    'setAlarm',
    'stopAlarm',
    'stopAll',
    'isRinging',
    'getAlarmState',
    'setWarningNotificationOnKill',
    'disableWarningNotificationOnKill',
  ];

  void install() {
    _handle('getPendingAlarmEvents', (_) => <Object?>[pending.toList()]);
    _handle('acknowledgeAlarmEvent', (args) {
      acknowledged.add((args![0]! as int, args[1]! as int));
      return <Object?>[null];
    });
    _handle('setAlarm', (_) {
      final error = setAlarmError;
      if (error != null) return <Object?>[error.code, error.message, null];
      return <Object?>[null];
    });
    _handle('stopAlarm', (_) => <Object?>[null]);
    _handle('stopAll', (_) => <Object?>[null]);
    _handle('isRinging', (args) {
      final id = args?[0] as int?;
      final result = id == null ? ringing.isNotEmpty : ringing.contains(id);
      return <Object?>[result];
    });
    _handle('getAlarmState', (args) {
      final id = args![0]! as int;
      final state = ringing.contains(id)
          ? AlarmStateWire.ringing
          : queued.contains(id)
              ? AlarmStateWire.queued
              : AlarmStateWire.inactive;
      return <Object?>[state];
    });
    _handle('setWarningNotificationOnKill', (_) => <Object?>[null]);
    _handle('disableWarningNotificationOnKill', (_) => <Object?>[null]);
  }

  void _handle(String name, Object? Function(List<Object?>? args) respond) {
    final channel = BasicMessageChannel<Object?>(
      '$_prefix$name',
      AlarmApi.pigeonChannelCodec,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, (message) async {
      calls.add(name);
      return respond(message as List<Object?>?);
    });
  }

  void remove() {
    for (final name in _methods) {
      final channel = BasicMessageChannel<Object?>(
        '$_prefix$name',
        AlarmApi.pigeonChannelCodec,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(channel, null);
    }
  }
}

/// Builds the wire event a user snooze produces.
///
/// `recordedAtMillis` defaults to the ring time, matching how the host treats a
/// marker written by an older plugin version: with nothing recording *when* it
/// was written, the ring time doubles as the acknowledgement key.
AlarmEventWire snoozeEvent(
  int alarmId,
  DateTime nextRingAt, {
  DateTime? recordedAt,
}) =>
    AlarmEventWire(
      alarmId: alarmId,
      verb: AlarmEventVerbWire.moved,
      cause: AlarmEventCauseWire.snooze,
      atMillis: nextRingAt.millisecondsSinceEpoch,
      recordedAtMillis: (recordedAt ?? nextRingAt).millisecondsSinceEpoch,
    );

/// Builds the wire event a stale-at-boot discard produces.
AlarmEventWire droppedEvent(
  int alarmId,
  DateTime scheduledFor, {
  DateTime? recordedAt,
}) =>
    AlarmEventWire(
      alarmId: alarmId,
      verb: AlarmEventVerbWire.dropped,
      cause: AlarmEventCauseWire.staleAtBoot,
      atMillis: scheduledFor.millisecondsSinceEpoch,
      recordedAtMillis: (recordedAt ?? scheduledFor).millisecondsSinceEpoch,
    );

/// Builds the wire event a ring the platform refused produces.
AlarmEventWire refusedRingEvent(
  int alarmId,
  DateTime nextRingAt, {
  DateTime? recordedAt,
}) =>
    AlarmEventWire(
      alarmId: alarmId,
      verb: AlarmEventVerbWire.moved,
      cause: AlarmEventCauseWire.platformRefusal,
      atMillis: nextRingAt.millisecondsSinceEpoch,
      recordedAtMillis: (recordedAt ?? nextRingAt).millisecondsSinceEpoch,
    );

/// Delivers an `alarmEvent` call the way the host would when an engine happens
/// to be attached, and completes only when Dart has finished handling it.
Future<void> hostReportsEvent(AlarmEventWire event) async {
  const channelName = 'dev.flutter.pigeon.alarm.AlarmTriggerApi.alarmEvent';
  final encoded = AlarmTriggerApi.pigeonChannelCodec.encodeMessage(
    <Object?>[event],
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channelName, encoded, (_) {});
}
