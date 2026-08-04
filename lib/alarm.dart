// Ignoring deprecated member use for backwards compatibility.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/service/alarm_storage.dart';
import 'package:alarm/src/alarm_trigger_api_impl.dart';
import 'package:alarm/src/android_alarm.dart';
import 'package:alarm/src/generated/platform_bindings.g.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:alarm/src/platform_timers.dart';
import 'package:alarm/utils/alarm_exception.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:alarm/utils/extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

export 'package:alarm/model/alarm_settings.dart';
export 'package:alarm/model/notification_settings.dart';
export 'package:alarm/model/volume_settings.dart';

/// Class that handles the alarm.
class Alarm {
  /// Whether it's iOS device.
  static bool get iOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether it's Android device.
  static bool get android => defaultTargetPlatform == TargetPlatform.android;

  static final _log = Logger('Alarm');

  static final _scheduled = BehaviorSubject<AlarmSet>.seeded(AlarmSet.empty());

  static final _ringing = BehaviorSubject<AlarmSet>.seeded(AlarmSet.empty());

  static final _snoozed =
      StreamController<({int id, DateTime nextRingAt})>.broadcast();

  /// Stream of the scheduled alarms.
  static ValueStream<AlarmSet> get scheduled => _scheduled.stream;

  /// Stream of the ringing alarms.
  static ValueStream<AlarmSet> get ringing => _ringing.stream;

  /// Stream of alarms deferred on the host side, with the instant each one
  /// rings again.
  ///
  /// A snooze never reaches [ringing] as a stop: the alarm is still owed, and
  /// an application tracking its own alarm state needs to record a deferral
  /// rather than a dismissal.
  static Stream<({int id, DateTime nextRingAt})> get snoozed => _snoozed.stream;

  /// Stream of the alarm updates.
  ///
  /// Uses a broadcast controller so events are not buffered when no client
  /// is listening.
  @Deprecated('Use [scheduled] and [ringing] streams instead.')
  static final updateStream = StreamController<int>.broadcast();

  /// Stream of the ringing status.
  ///
  /// Uses a broadcast controller so events are not buffered when no client
  /// is listening.
  @Deprecated('Use [scheduled] and [ringing] streams instead.')
  static final ringStream = StreamController<AlarmSettings>.broadcast();

  /// Initializes Alarm services.
  ///
  /// Also calls [checkAlarm] that will reschedule alarms that were set before
  /// app termination.
  static Future<void> init() async {
    AlarmTriggerApiImpl.ensureInitialized(
      alarmRang: alarmRang,
      alarmStopped: _alarmStopped,
      alarmSnoozed: _alarmSnoozed,
    );

    await AlarmStorage.init();

    await checkAlarm();
  }

  /// Checks if some alarms were set on previous session.
  /// If it's the case then reschedules them.
  ///
  /// Single-flight: concurrent callers share one pass rather than interleaving
  /// two reconciliations over the same alarms.
  static Future<void> checkAlarm() =>
      _checkAlarmFuture ??= _checkAlarm().whenComplete(() {
        _checkAlarmFuture = null;
      });

  static Future<void>? _checkAlarmFuture;

  static Future<void> _checkAlarm() async {
    final snoozed = await _applyPendingSnoozes();

    final alarms = await getAlarms();

    if (iOS) await stopAll();

    for (final alarm in alarms) {
      // Just reconciled from a snooze marker: the native alarm is already
      // armed for the new time and both stores agree, so set() would only
      // cancel and re-arm it — and stop() inside set() reports a spurious
      // alarmStopped on the way through.
      if (snoozed.contains(alarm.id)) continue;

      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        await set(alarmSettings: alarm);
      } else {
        // Query the platform directly instead of [isRinging] because the
        // ringing stream is not populated yet at this point, which would
        // trigger the defensive consistency logs for no reason.
        final isRinging = iOS
            ? await IOSAlarm().isRinging(alarm.id)
            : await AndroidAlarm().isRinging(alarm.id);
        if (isRinging) {
          _ringing.add(_ringing.value.add(alarm));
          ringStream.add(alarm);
        } else {
          // Re-read before destroying anything. Every await above is a window
          // in which a snooze can land, and the snapshot this loop iterates
          // would still show the pre-snooze time — stopping here would cancel a
          // deferral the user just asked for.
          final current = await getAlarm(alarm.id);
          if (current != null && current.dateTime.isAfter(DateTime.now())) {
            _log.info('Alarm ${alarm.id} moved to ${current.dateTime} while '
                'reconciling, so it is left scheduled.');
            continue;
          }
          await stop(alarm.id);
        }
      }
    }
  }

  /// Schedules an alarm with given [alarmSettings] with its notification.
  ///
  /// If you set an alarm for the same dateTime as an existing one,
  /// the new alarm will replace the existing one.
  static Future<bool> set({required AlarmSettings alarmSettings}) async {
    alarmSettingsValidation(alarmSettings);

    final alarms = await getAlarms();

    for (final alarm in alarms) {
      final sameId = alarm.id == alarmSettings.id;
      final sameSecond = alarm.dateTime.isSameSecond(alarmSettings.dateTime);
      final shouldReplaceSameSecond =
          sameSecond && !alarmSettings.allowSameSecondScheduling;

      if (sameId || shouldReplaceSameSecond) {
        await Alarm.stop(alarm.id);
      }
    }

    await AlarmStorage.saveAlarm(alarmSettings);

    final success = iOS
        ? await IOSAlarm().setAlarm(alarmSettings)
        : await AndroidAlarm().setAlarm(alarmSettings);

    if (success) {
      _scheduled.add(_scheduled.value.add(alarmSettings));
      _ringing.add(_ringing.value.remove(alarmSettings));
      updateStream.add(alarmSettings.id);
    }

    return success;
  }

  /// Returns this class to the state a fresh isolate would see.
  ///
  /// Only for tests. [scheduled] and [ringing] are static subjects and
  /// [checkAlarm] is single-flight, so without this one test's alarms and
  /// in-flight reconciliation are still there for the next one. Reset
  /// `AlarmStorage` and `AlarmTriggerApiImpl` alongside it.
  @visibleForTesting
  static void resetForTesting() {
    _checkAlarmFuture = null;
    _scheduled.add(AlarmSet.empty());
    _ringing.add(AlarmSet.empty());
    PlatformTimers.stopAll();
  }

  /// Validates [alarmSettings] fields.
  static void alarmSettingsValidation(AlarmSettings alarmSettings) {
    if (alarmSettings.id == 0 || alarmSettings.id == -1) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message: 'Alarm id cannot be 0 or -1. Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.id > 2147483647) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message:
            'Alarm id cannot be set larger than Int max value (2147483647). '
            'Provided: ${alarmSettings.id}',
      );
    }
    if (alarmSettings.id < -2147483648) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message:
            'Alarm id cannot be set smaller than Int min value (-2147483648). '
            'Provided: ${alarmSettings.id}',
      );
    }

    final snoozeDuration = alarmSettings.androidSnoozeDuration;
    if (snoozeDuration != null && snoozeDuration <= Duration.zero) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message: 'androidSnoozeDuration must be positive. '
            'Provided: $snoozeDuration',
      );
    }

    // Everything below only warns. These settings are inert on iOS, and
    // NotificationSettings is shared across platforms, so throwing would break
    // apps that configure a snooze label once for both.
    final snoozeLabel = alarmSettings.notificationSettings.androidSnoozeButton;
    final snoozeIsUsable = snoozeDuration != null &&
        snoozeDuration >= AlarmSettings.minSnoozeDuration;

    if (snoozeDuration != null && !snoozeIsUsable) {
      _log.warning(
        'Alarm ${alarmSettings.id} has androidSnoozeDuration $snoozeDuration, '
        'which is below the ${AlarmSettings.minSnoozeDuration} minimum, so no '
        'snooze will be offered.',
      );
    }
    if (snoozeLabel != null && !snoozeIsUsable) {
      _log.warning(
        'Alarm ${alarmSettings.id} sets a snooze button labelled '
        '"$snoozeLabel" but no usable androidSnoozeDuration, so the button '
        'will not be shown.',
      );
    }
    if (snoozeIsUsable && snoozeLabel == null) {
      _log.warning(
        'Alarm ${alarmSettings.id} has an androidSnoozeDuration but no '
        'NotificationSettings.androidSnoozeButton label, so the notification '
        'will not offer a snooze.',
      );
    }

    final notification = alarmSettings.notificationSettings;
    if (!notification.androidStopAlarmOnDismiss &&
        notification.stopButton == null) {
      _log.warning(
        'Alarm ${alarmSettings.id} turns off androidStopAlarmOnDismiss and '
        'sets no stopButton, so its notification offers no way to stop the '
        'alarm. Give it a stopButton, or present the alarm on a screen of '
        'your own.',
      );
    }
  }

  /// When the app is killed, all the processes are terminated
  /// so the alarm may never ring. By default, to warn the user, a notification
  /// is shown at the moment he kills the app.
  /// This methods allows you to customize this notification content.
  ///
  /// [title] default value is `Your alarm may not ring`
  ///
  /// [body] default value is `You killed the app.
  /// Please reopen so your alarm can ring.`
  static Future<void> setWarningNotificationOnKill(
    String title,
    String body,
  ) async {
    if (iOS) await IOSAlarm().setWarningNotificationOnKill(title, body);
    if (android) await AndroidAlarm().setWarningNotificationOnKill(title, body);
  }

  /// Stops alarm.
  static Future<bool> stop(int id) async {
    await AlarmStorage.unsaveAlarm(id);
    updateStream.add(id);

    final success = iOS
        ? await IOSAlarm().stopAlarm(id)
        : await AndroidAlarm().stopAlarm(id);

    if (success) {
      _scheduled.add(_scheduled.value.removeById(id));
      _ringing.add(_ringing.value.removeById(id));
    }

    return success;
  }

  /// Stops all the alarms.
  static Future<void> stopAll() async {
    final alarms = await getAlarms();

    iOS ? await IOSAlarm().stopAll() : await AndroidAlarm().stopAll();

    await AlarmStorage.unsaveAll();

    for (final alarm in alarms) {
      updateStream.add(alarm.id);
    }

    _scheduled.add(AlarmSet.empty());
    _ringing.add(AlarmSet.empty());
  }

  /// Whether the alarm is ringing.
  ///
  /// If no `id` is provided, it checks if any alarm is ringing.
  /// If an `id` is provided, it checks if the specific alarm with that `id`
  /// is ringing.
  static Future<bool> isRinging([int? id]) async {
    final isRinging = iOS
        ? await IOSAlarm().isRinging(id)
        : await AndroidAlarm().isRinging(id);

    // Defensive programming: check if the stream status matches the platform
    // reported status.
    if (id != null) {
      final alarm = await getAlarm(id);
      if (alarm == null) {
        if (_scheduled.value.containsId(id)) {
          _log.severe('Alarm with id $id was not found but was '
              'ringing=$isRinging and marked as scheduled.');
        }
        if (_ringing.value.containsId(id)) {
          _log.severe('Alarm with id $id was not found but was '
              'ringing=$isRinging and marked as ringing.');
        }
      } else {
        if (isRinging != _ringing.value.contains(alarm)) {
          _log.severe('Alarm with id $id is ringing=$isRinging but was '
              'not marked as such.');
        }
      }
    }

    return isRinging;
  }

  /// Whether an alarm is set.
  static Future<bool> hasAlarm() => AlarmStorage.hasAlarm();

  /// Returns alarm by given id. Returns null if not found.
  static Future<AlarmSettings?> getAlarm(int id) async {
    final alarms = await getAlarms();

    for (final alarm in alarms) {
      if (alarm.id == id) return alarm;
    }
    _log.warning('Alarm with id $id not found.');

    return null;
  }

  /// Returns all the alarms.
  static Future<List<AlarmSettings>> getAlarms() =>
      AlarmStorage.getSavedAlarms();

  /// PRIVATE: Called by the native platform when the alarm rings.
  static void alarmRang(AlarmSettings alarm) {
    _scheduled.add(_scheduled.value.remove(alarm));
    _ringing.add(_ringing.value.add(alarm));
    ringStream.add(alarm);
  }

  /// Applies snoozes the host recorded while no isolate was listening.
  ///
  /// The notification is native and a full screen intent starts the process
  /// without starting Flutter, so a deferral taken there is normally observed
  /// only here. Runs before [checkAlarm]'s reschedule loop: until the shifted
  /// time is in Dart storage, that loop sees the original past time and stops
  /// the alarm, undoing the snooze.
  ///
  /// Ids that were applied here are returned so the caller can leave them
  /// alone — the native alarm and native storage are already correct, so
  /// rescheduling them would cancel and re-arm for no reason.
  static Future<Set<int>> _applyPendingSnoozes() async {
    final List<PendingSnoozeWire> pending;
    try {
      pending = await AlarmApi().getPendingSnoozes();
    } on Object catch (error) {
      // Never let this break init: fall through to the normal reschedule loop.
      _log.warning('Could not read pending snoozes: $error');
      return {};
    }

    final applied = <int>{};
    for (final snooze in pending) {
      final nextRingAt =
          DateTime.fromMillisecondsSinceEpoch(snooze.millisecondsSinceEpoch);
      try {
        if (await _applySnooze(snooze.alarmId, nextRingAt)) {
          applied.add(snooze.alarmId);
        }
        // Acknowledged either way: an applied snooze is durable, and one that
        // could not be applied is not going to become applicable later.
        await AlarmApi().acknowledgeSnooze(
          alarmId: snooze.alarmId,
          nextRingAtMillis: snooze.millisecondsSinceEpoch,
        );
      } on Object catch (error) {
        _log.warning('Could not apply snooze ${snooze.alarmId}: $error');
      }
    }
    return applied;
  }

  /// PRIVATE: Called by the native platform when an alarm was deferred there.
  static Future<void> _alarmSnoozed(int alarmId, DateTime nextRingAt) async {
    await _applySnooze(alarmId, nextRingAt);
  }

  /// Moves [alarmId] to [nextRingAt] in Dart's own state, and reports it.
  ///
  /// Shared by the live callback and startup reconciliation so both produce
  /// the same result. Idempotent: applying a snooze already applied changes
  /// nothing and emits nothing.
  ///
  /// Returns whether the alarm now rings at [nextRingAt].
  static Future<bool> _applySnooze(int alarmId, DateTime nextRingAt) async {
    final alarm = await getAlarm(alarmId);
    if (alarm == null) {
      _log.severe('Alarm $alarmId was snoozed but is not in storage, so the '
          'deferral cannot be applied. The alarm will not ring again.');
      return false;
    }

    // A marker whose time has already passed would rewrite the alarm to a past
    // time, which checkAlarm then deletes. Refuse rather than destroy it.
    if (!nextRingAt.isAfter(DateTime.now())) {
      _log.warning('Ignoring snooze for $alarmId: $nextRingAt is not in the '
          'future.');
      return false;
    }

    // Whether this deferral is news. A marker replayed after the stored time
    // already moved has nothing to write — but that is not the same as having
    // nothing to do, because process-local state does not survive a restart.
    final isNewDeferral = alarm.dateTime.isBefore(nextRingAt);
    final snoozedAlarm =
        isNewDeferral ? alarm.copyWith(dateTime: nextRingAt) : alarm;

    if (isNewDeferral) await AlarmStorage.saveAlarm(snoozedAlarm);

    // Reconciled every time, including for an already-applied marker. A fresh
    // isolate starts with empty sets and no timers whatever storage says, and
    // [checkAlarm] skips the ids applied here, so this is the only thing that
    // surfaces them. The fallback timer also still holds the pre-snooze time,
    // and left alone it fires immediately on the next foreground and reports a
    // phantom ring, which would evict the snoozed alarm from [scheduled].
    PlatformTimers.stopAlarm(alarmId);
    PlatformTimers.setAlarm(snoozedAlarm);

    final nextRinging = _ringing.value.removeById(alarmId);
    if (nextRinging != _ringing.value) _ringing.add(nextRinging);

    final nextScheduled =
        _scheduled.value.removeById(alarmId).add(snoozedAlarm);
    if (nextScheduled != _scheduled.value) _scheduled.add(nextScheduled);

    // Only a deferral that actually moved the alarm is an event.
    if (isNewDeferral) {
      _snoozed.add((id: alarmId, nextRingAt: nextRingAt));
      updateStream.add(alarmId);
    }
    return true;
  }

  static Future<void> _alarmStopped(int alarmId) async {
    // Incase the alarm was stopped via the platform (e.g. notification action),
    // we need to make sure it is deleted from storage.
    await AlarmStorage.unsaveAlarm(alarmId);

    _scheduled.add(_scheduled.value.removeById(alarmId));
    _ringing.add(_ringing.value.removeById(alarmId));

    updateStream.add(alarmId);
  }
}
