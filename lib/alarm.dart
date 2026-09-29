// Ignoring deprecated member use for backwards compatibility.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import 'package:alarm/model/alarm_event.dart';
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

export 'package:alarm/model/alarm_event.dart';
export 'package:alarm/model/alarm_settings.dart';
export 'package:alarm/model/notification_settings.dart';
export 'package:alarm/model/volume_settings.dart';

/// What applying one host event did.
///
/// `handled` means `checkAlarm` should leave this alarm alone: native storage
/// and the native alarm are already correct, so rescheduling would cancel and
/// re-arm for no reason. `reported` means the event reached [Alarm.events], so
/// an application listener may be part-way through acting on it — which is the
/// only case where who acknowledges it can matter.
typedef _EventOutcome = ({bool handled, bool reported});

/// Class that handles the alarm.
class Alarm {
  /// Whether it's iOS device.
  static bool get iOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether it's Android device.
  static bool get android => defaultTargetPlatform == TargetPlatform.android;

  static final _log = Logger('Alarm');

  static final _scheduled = BehaviorSubject<AlarmSet>.seeded(AlarmSet.empty());

  static final _ringing = BehaviorSubject<AlarmSet>.seeded(AlarmSet.empty());

  /// How many events a listener that subscribes late still receives.
  ///
  /// Has to cover one whole drain, or "subscribing after [init] is safe" is
  /// only true for small alarm sets. The host holds one marker per alarm, so a
  /// single [init] can emit one event per stored alarm, and Android caps an app
  /// at 500 scheduled alarms — see `AlarmScheduler`, where exceeding it is the
  /// reachable arming failure. Sized above that cap so a drain cannot overflow
  /// it and silently drop the oldest events.
  static const _eventReplayBufferSize = 512;

  static ReplaySubject<AlarmEvent> _events = _newEventSubject();

  /// Whether the plugin acknowledges an event on the application's behalf.
  ///
  /// Moved only by an [init] that names it. True keeps 5.10.0's behaviour,
  /// where the host's marker is dropped as soon as the event has been emitted;
  /// false moves that boundary to [acknowledgeEvent], so the marker outlives a
  /// process death while the application is still writing the event down.
  static bool _acknowledgeEventsAutomatically = true;

  /// Events already emitted on [events] in this isolate, keyed by
  /// `(id, recordedAt)` — the identity the stream documents.
  ///
  /// Two jobs, both of which need exactly this set. It suppresses a drop the
  /// live callback and the drain both deliver, and it is how
  /// [_acknowledgeUnlessOwned] tells an event the application already has from
  /// one it will never see: a marker replayed inside a single run must not be
  /// acknowledged out from under a handler that is still writing down the copy
  /// it was given the first time.
  ///
  /// Held for [_reportedEventRetention]. "One entry per alarm at startup" was
  /// the bound while this held drops alone — one marker per stored alarm, all
  /// drained at init — but a live snooze mints a new key every time, so a
  /// long-running process can emit moves indefinitely.
  ///
  /// Swept whenever an event is emitted *and* at the top of every drain, so a
  /// process that stops seeing events still clears out at its next [init] or
  /// [checkAlarm] rather than holding its last burst until it exits.
  static final Set<(int, int)> _reportedEvents = <(int, int)>{};

  /// How long a reported event is remembered.
  ///
  /// The host expires a `moved` marker after a week and a `dropped` one after
  /// 24 h, so past the longest of those no marker can come back and
  /// remembering it suppresses nothing. Sized a day above the longest so the
  /// entry always outlives the marker it guards against.
  static const _reportedEventRetention = Duration(days: 8);

  /// Records that [key] was emitted, sweeping first.
  static void _rememberReported((int, int) key) {
    _pruneReportedEvents();
    _reportedEvents.add(key);
  }

  /// Drops keys no surviving marker can still carry.
  static void _pruneReportedEvents() {
    final cutoff =
        DateTime.now().subtract(_reportedEventRetention).millisecondsSinceEpoch;
    _reportedEvents.removeWhere((remembered) => remembered.$2 < cutoff);
  }

  static ReplaySubject<AlarmEvent> _newEventSubject() =>
      ReplaySubject<AlarmEvent>(maxSize: _eventReplayBufferSize);

  /// Stream of the scheduled alarms.
  static ValueStream<AlarmSet> get scheduled => _scheduled.stream;

  /// Stream of the ringing alarms.
  static ValueStream<AlarmSet> get ringing => _ringing.stream;

  /// Stream of alarms deferred on the host side, with the instant each one
  /// rings again.
  ///
  /// **Deprecated. Listen to [events] and filter on [AlarmEventCause.snooze]
  /// instead**, which reports the same deferrals and carries one more field.
  ///
  /// That field is the one a manual acknowledgement boundary needs. A
  /// subscriber here is handed `(id, nextRingAt)`, while [acknowledgeEvent]
  /// needs the event's `recordedAt`, so there is nothing to acknowledge with.
  /// Under `Alarm.init(acknowledgeEventsAutomatically: false)` the host keeps
  /// an unacknowledged snooze marker for a week and re-emits it on every
  /// [init], so a listener that shows the user a snackbar would show it again
  /// on every launch until then, and no care taken in the application can
  /// prevent it. That dead end is also why automatic acknowledgement stayed
  /// the default rather than becoming a staged migration; see [events].
  ///
  /// Everything below still holds while it remains.
  ///
  /// A snooze never reaches [ringing] as a stop: the alarm is still owed, and
  /// an application tracking its own alarm state needs to record a deferral
  /// rather than a dismissal.
  ///
  /// Only covers user snoozes. [events] reports every change the host makes to
  /// an alarm on its own, including deferrals the platform forced and alarms
  /// discarded as stale.
  ///
  /// A view over [events] rather than a stream of its own, so the two can never
  /// disagree about a deferral, and so this inherits the buffering described
  /// there: subscribing after [init] still delivers a snooze replayed during
  /// it. Before that it was a plain broadcast stream, and a deferral taken with
  /// no engine running reached only listeners that already existed — which the
  /// documented `await Alarm.init()` in `main` made unlikely.
  @Deprecated('Use [events] and filter on [AlarmEventCause.snooze].')
  static Stream<({int id, DateTime nextRingAt})> get snoozed => _events.stream
      .where(
        (event) => event is AlarmMoved && event.cause == AlarmEventCause.snooze,
      )
      .cast<AlarmMoved>()
      .map((event) => (id: event.id, nextRingAt: event.nextRingAt));

  /// Stream of changes the host made to alarms without the app asking.
  ///
  /// The host takes these decisions where no Flutter engine is running — a
  /// native notification action, a full screen intent, the boot receiver — so
  /// they are recorded durably and drained on the next [init]. An event can
  /// therefore arrive long after it happened.
  ///
  /// **Buffered, so subscribing after [init] is safe.** The documented way to
  /// start the plugin is `await Alarm.init()` in `main`, which means the
  /// realistic listener attaches later — and an [AlarmDropped] can *only* be
  /// discovered during that drain, because the alarm was discarded at boot with
  /// no engine to call. An unbuffered stream would therefore never deliver the
  /// case this exists for. Each new listener receives the last
  /// [_eventReplayBufferSize] events.
  ///
  /// **Delivered at least once, not exactly once.** The host keeps its marker
  /// until Dart acknowledges it, so a process death before that acknowledgement
  /// replays the event on the next [init] — losing it would be the worse
  /// failure. Re-subscribing also replays. The plugin suppresses the repeats it
  /// can detect, but an application that acts irreversibly on an event —
  /// posting a notification, writing a log row — should key that action on
  /// `(id, recordedAt)`, which identifies an event uniquely.
  ///
  /// **By default the acknowledgement does not wait for this stream's
  /// listeners.** It is sent once the event has been *emitted*, and a stream
  /// discards whatever future a handler returns, so a handler that persists the
  /// event is still in flight when the host's marker is deleted — and depending
  /// on channel latency it may not have started. A process death in that window
  /// loses the event for good: the durable record is gone, and the replay
  /// buffer above is in memory. It costs least for an [AlarmMoved], where the
  /// new time is already stored on both sides and only the notice is lost, and
  /// most for an [AlarmDropped], which is the only evidence the alarm did not
  /// ring.
  ///
  /// **Pass `acknowledgeEventsAutomatically: false` to [init] to close that
  /// window.** The host then keeps its marker until the application calls
  /// [acknowledgeEvent], so the boundary sits where the durable work happens
  /// instead of one statement after the emit. The cost is that an event the
  /// application never acknowledges is redelivered until the marker expires;
  /// see [acknowledgeEvent].
  ///
  /// Automatic acknowledgement stays the default rather than becoming a staged
  /// migration, because [snoozed] cannot take part in the manual boundary: it
  /// hands its subscriber `(id, nextRingAt)`, and [acknowledgeEvent] needs the
  /// event's `recordedAt`. Making the manual path mandatory would leave that
  /// stream replaying every deferral on each launch with nothing able to
  /// acknowledge it. Consume this stream instead if you want the boundary —
  /// [snoozed] is deprecated for that reason, which is the other half of the
  /// same decision.
  ///
  /// The plugin deliberately shows the user nothing for these. An
  /// [AlarmDropped] in particular is worth surfacing, but only the application
  /// can do it in its own voice and its own records.
  static Stream<AlarmEvent> get events => _events.stream;

  /// Confirms the application has durably taken responsibility for [event].
  ///
  /// Only changes anything under
  /// `Alarm.init(acknowledgeEventsAutomatically: false)`. Under the default the
  /// plugin has already acknowledged on the application's behalf, so the call
  /// still goes to the host and simply finds nothing to drop. Harmless, but not
  /// free — a listener written for the manual boundary is safe to run either
  /// way, at the cost of one platform round trip per event.
  ///
  /// **Call it after the work that must not be lost, not when the event
  /// arrives.** The whole point of taking the boundary is that the host's
  /// marker outlives a process death while the application is still writing
  /// the event down; acknowledging first gives that up and leaves the default
  /// behaviour with extra steps.
  ///
  /// **An event that is never acknowledged is redelivered on every [init]**
  /// until the host's marker expires — 24 h for an [AlarmDropped], a week for
  /// an [AlarmMoved]. That is the cost of the manual boundary, and the reason
  /// it is opt-in: an application that takes it has to acknowledge every event
  /// it is given, including ones it decides to ignore. Redelivery is not
  /// duplication in the harmful sense, since `(id, recordedAt)` identifies an
  /// event uniquely, but it is work the application has to be ready to skip.
  ///
  /// Safe to call more than once for the same event.
  static Future<void> acknowledgeEvent(AlarmEvent event) =>
      AlarmApi().acknowledgeAlarmEvent(
        alarmId: event.id,
        recordedAtMillis: event.recordedAt.millisecondsSinceEpoch,
      );

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
  ///
  /// Pass `acknowledgeEventsAutomatically: false` to take the durability
  /// boundary for [events] yourself; see [acknowledgeEvent] for what that
  /// costs and what it buys. Defaults to `true`, which is 5.10.0's behaviour,
  /// and stays that way: an advanced opt-in rather than a future default, for
  /// the reason given on [events].
  ///
  /// **Omitting it leaves the boundary as it is**, rather than restoring the
  /// default. This is callable more than once — on resume, or from a second
  /// library path — and a bare call is not an application changing its mind
  /// about durability, so it must not be able to hand the boundary back and
  /// start acknowledging events the application still owns. Only an explicit
  /// value moves it, in either direction.
  ///
  /// The setting is per-isolate. It lives in static state that starts at the
  /// default, so an isolate the application spawns does not inherit an opt-out
  /// taken in the main one: it begins acknowledging automatically, and a bare
  /// [init] there would acknowledge markers the main isolate still owns. The
  /// plugin spawns none itself, so this only reaches an application that
  /// creates one and calls into [Alarm] from it — which then has to pass the
  /// value explicitly in every isolate rather than once at startup.
  static Future<void> init({bool? acknowledgeEventsAutomatically}) async {
    // Before anything that can drain: [checkAlarm] below applies pending
    // events, and it has to already know who owns their acknowledgement.
    if (acknowledgeEventsAutomatically != null) {
      if (acknowledgeEventsAutomatically && !_acknowledgeEventsAutomatically) {
        _log.warning(
          'Alarm.init(acknowledgeEventsAutomatically: true) is undoing an '
          'earlier opt-out. Events already delivered but not yet acknowledged '
          'are acknowledged for the application from now on, so a process '
          'death while a handler is still writing one down loses it.',
        );
      }
      _acknowledgeEventsAutomatically = acknowledgeEventsAutomatically;
    }

    AlarmTriggerApiImpl.ensureInitialized(
      alarmRang: alarmRang,
      alarmStopped: _alarmStopped,
      alarmEvent: _alarmEvent,
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

  /// How long past its due time an alarm the platform does not report as
  /// ringing is still left alone by [checkAlarm].
  ///
  /// An alarm due at 06:00:00.000 is not audible at 06:00:00.000. On Android
  /// the broadcast has to be delivered, the process may have to start, the
  /// foreground service has to come up and the player has to prepare, and the
  /// alarm only counts as ringing at the end of all that — so a reconciliation
  /// landing in that gap cannot tell "already fired and was stopped" from
  /// "about to sound". Cancelling the second is by far the worse mistake: the
  /// alarm never rings, and every signal the app has says it was set.
  ///
  /// Generous on purpose, because the two outcomes are not comparable. Sparing
  /// an alarm that really did fail costs a stale entry in storage; stopping one
  /// that was about to ring costs the user their morning.
  ///
  /// A spared alarm is not tidied up on a timer. [checkAlarm] runs only when it
  /// is called — in practice from [init] — so an alarm that genuinely failed
  /// can sit in storage until the next pass. That is an accepted risk rather
  /// than a harmless one: the entry may be an inexact alarm still pending and
  /// about to ring late, which is exactly what this window protects, and a
  /// native record that survives a reboot is re-armed by `BootReceiver`.
  /// Scheduling a follow-up reconciliation was considered and rejected — a
  /// timer would not fire in a background isolate that gets torn down, and it
  /// could stop an alarm at the moment the user is acting on it.
  ///
  /// Does not cover an alarm delayed past this window by the inexact fallback
  /// `AlarmScheduler` uses when the exact alarm permission is revoked. Telling
  /// "armed and still pending" from "never armed" needs durable native state,
  /// which the platform does not expose today.
  static const _ringStartGrace = Duration(seconds: 30);

  static Future<void> _checkAlarm() async {
    final handled = await _applyPendingEvents();

    final alarms = await getAlarms();

    if (iOS) await stopAll();

    for (final alarm in alarms) {
      // Just reconciled from a host event: for a move the native alarm is
      // already armed for the new time and both stores agree, so set() would
      // only cancel and re-arm it — and stop() inside set() reports a spurious
      // alarmStopped on the way through. For a drop the alarm is already gone.
      if (handled.contains(alarm.id)) continue;

      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        await set(alarmSettings: alarm);
      } else {
        // Query the platform directly instead of [isRinging] because the
        // ringing stream is not populated yet at this point, which would
        // trigger the defensive consistency logs for no reason.
        final state = iOS
            ? await IOSAlarm().getAlarmState(alarm.id)
            : await AndroidAlarm().getAlarmState(alarm.id);
        if (state == AlarmStateWire.ringing) {
          _ringing.add(_ringing.value.add(alarm));
          ringStream.add(alarm);
        } else if (state == AlarmStateWire.queued) {
          _log.info('Alarm ${alarm.id} is queued behind another alarm, so it '
              'is left scheduled.');
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

          // Read from [current] like the branch above, so both agree on the
          // authoritative time. Android only: iOS arrives here having already
          // been through [stopAll], which leaves [current] null and nothing to
          // spare, so the gate is really documenting whose delivery chain this
          // is about.
          if (android && current != null) {
            final overdue = DateTime.now().difference(current.dateTime);
            if (overdue < _ringStartGrace) {
              _log.info('Alarm ${alarm.id} came due '
                  '${overdue.inMilliseconds}ms ago and is not audible yet, so '
                  'it is left alone rather than stopped.');
              continue;
            }
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
    // Replaced rather than drained: [events] replays its buffer to every new
    // listener, so without this the events of one test are delivered to the
    // next one's listener.
    _events = _newEventSubject();
    _reportedEvents.clear();
    _acknowledgeEventsAutomatically = true;
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

    final staleAfter = alarmSettings.androidStaleAfter;
    if (staleAfter != null && staleAfter < _ringStartGrace) {
      throw AlarmException(
        AlarmErrorCode.invalidArguments,
        message: 'androidStaleAfter cannot be shorter than the '
            '${_ringStartGrace.inSeconds}s grace [checkAlarm] gives an alarm '
            'that is due but not yet ringing, or Dart would spare an alarm '
            'the boot path had already discarded. Provided: $staleAfter',
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
        'sets no stopButton, so its notification comes back after a swipe but '
        'still offers no way to stop the alarm. Give it a stopButton, or '
        'present the alarm on a screen of your own.',
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

  /// Applies changes the host recorded while no isolate was listening.
  ///
  /// The notification is native, a full screen intent starts the process
  /// without starting Flutter, and the boot receiver runs before any app code,
  /// so a
  /// decision taken in those places is normally observed only here. Runs before
  /// [checkAlarm]'s reschedule loop: until a deferral is in Dart storage, that
  /// loop sees the original past time and stops the alarm, undoing it.
  ///
  /// Ids that were applied here are returned so the caller can leave them
  /// alone — the native alarm and native storage are already correct, so
  /// rescheduling them would cancel and re-arm for no reason.
  static Future<Set<int>> _applyPendingEvents() async {
    final List<AlarmEventWire> pending;
    try {
      pending = await AlarmApi().getPendingAlarmEvents();
    } on Object catch (error) {
      // Never let this break init: fall through to the normal reschedule loop.
      _log.warning('Could not read pending alarm events: $error');
      return {};
    }

    _pruneReportedEvents();

    final applied = <int>{};
    for (final wire in pending) {
      try {
        // Read once, before the event is applied, and used for every decision
        // about it. [init] can land mid-drain and name a new policy, and an
        // event handed to the application under the manual boundary must not
        // then be acknowledged for it because the flag moved while a handler
        // was running. A policy change takes effect from the next event.
        final acknowledgeAutomatically = _acknowledgeEventsAutomatically;
        final event = AlarmEvent.fromWire(wire);
        final outcome = await _applyEvent(event, acknowledgeAutomatically);
        if (outcome.handled) applied.add(wire.alarmId);
        await _acknowledgeUnlessOwned(
          outcome,
          event,
          acknowledgeAutomatically,
        );
      } on Object catch (error) {
        _log.warning('Could not apply alarm event ${wire.alarmId}: $error');
      }
    }
    return applied;
  }

  /// Acknowledges [event] unless the application has taken that boundary.
  ///
  /// An event the application was never given is always acknowledged here,
  /// whatever the mode. Nobody else can: it never reached [events], so no
  /// listener knows it exists, and leaving its marker would redeliver it on
  /// every [init] until it expired. Under the default that covers a deferral
  /// an earlier run already applied; under either mode it covers one that
  /// could not be applied at all. Neither becomes applicable later.
  ///
  /// An event this isolate *did* hand over is the only case the opt-out
  /// changes, and it is the case the boundary exists for: the marker is the
  /// application's last chance to see it again if this process dies while the
  /// handler is still writing it down. That includes a repeat suppressed by
  /// [_reportedEvents] — suppressed *because* the application already has it,
  /// which is exactly why this run must not acknowledge it.
  static Future<void> _acknowledgeUnlessOwned(
    _EventOutcome outcome,
    AlarmEvent event,
    bool acknowledgeAutomatically,
  ) async {
    if (outcome.reported && !acknowledgeAutomatically) return;
    await acknowledgeEvent(event);
  }

  /// PRIVATE: Called by the native platform when it changed an alarm itself.
  ///
  /// Acknowledges under the same rule as the drain. The host used to do this
  /// itself once this call returned, which put the boundary back where it
  /// cannot see whether a listener has finished — so the acknowledgement is
  /// Dart's on both paths now, and this one is the reason the opt-out means
  /// anything for a live event.
  static Future<void> _alarmEvent(AlarmEvent event) async {
    final acknowledgeAutomatically = _acknowledgeEventsAutomatically;
    final outcome = await _applyEvent(event, acknowledgeAutomatically);
    await _acknowledgeUnlessOwned(outcome, event, acknowledgeAutomatically);
  }

  /// Applies [event] to Dart's own state, and reports it.
  ///
  /// Shared by the live callback and startup reconciliation so both produce the
  /// same result, which matters because which one arrives first depends only on
  /// whether an engine happened to be attached.
  ///
  /// See [_EventOutcome] for what the result means.
  static Future<_EventOutcome> _applyEvent(
    AlarmEvent event,
    bool acknowledgeAutomatically,
  ) async {
    switch (event) {
      case AlarmMoved():
        return _applyMove(event, acknowledgeAutomatically);
      case AlarmDropped():
        return _applyDrop(event);
    }
  }

  /// Removes an alarm the host has already discarded, and reports it.
  ///
  /// Nothing is cancelled here: the host dropped it before recording the event,
  /// so this only brings Dart's own store and streams into line and tells the
  /// application, which is the whole reason the event exists.
  static Future<_EventOutcome> _applyDrop(AlarmDropped event) async {
    // Suppresses only the repeats this isolate can be certain of: the live
    // callback racing the drain, or two drains in one run.
    //
    // A replay from a *different* run is deliberately reported again. Removing
    // the alarm is durable and completes before the report, so a process death
    // in between leaves the marker with the alarm already gone — and treating
    // "the alarm is missing" as proof it was reported would swallow the only
    // notice the application ever gets. A duplicate is covered by the
    // documented `(id, recordedAt)` key; silence is not recoverable.
    final key = (event.id, event.recordedAt.millisecondsSinceEpoch);
    final alreadyReported = _reportedEvents.contains(key);
    if (!alreadyReported) _rememberReported(key);

    await AlarmStorage.unsaveAlarm(event.id);
    PlatformTimers.stopAlarm(event.id);

    _scheduled.add(_scheduled.value.removeById(event.id));
    _ringing.add(_ringing.value.removeById(event.id));

    if (alreadyReported) {
      _log.info('Alarm ${event.id} was already reported as dropped in this '
          'session; not reporting it again.');
      // Suppressed because the application already has it, which is not the
      // same as never having been given it: this run handed the event over the
      // first time, so this run must not acknowledge it on the app's behalf.
      return (handled: true, reported: true);
    }

    _events.add(event);
    updateStream.add(event.id);

    _log.info('Alarm ${event.id} was dropped by the host '
        '(${event.cause.name}); it should have rung at '
        '${event.scheduledFor}.');
    return (handled: true, reported: true);
  }

  /// Moves an alarm to its new time in Dart's own state, and reports it.
  ///
  /// Idempotent: applying a move already applied changes nothing and emits
  /// nothing.
  static Future<_EventOutcome> _applyMove(
    AlarmMoved event,
    bool acknowledgeAutomatically,
  ) async {
    final alarmId = event.id;
    final nextRingAt = event.nextRingAt;

    final alarm = await getAlarm(alarmId);
    if (alarm == null) {
      _log.severe('Alarm $alarmId was moved but is not in storage, so the '
          'deferral cannot be applied. The alarm will not ring again.');
      return (handled: false, reported: false);
    }

    // A marker whose time has already passed would rewrite the alarm to a past
    // time, which checkAlarm then deletes. Refuse rather than destroy it.
    if (!nextRingAt.isAfter(DateTime.now())) {
      _log.warning('Ignoring move for $alarmId: $nextRingAt is not in the '
          'future.');
      return (handled: false, reported: false);
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

    // Only a deferral that actually moved the alarm is an event. [snoozed] is a
    // view over this, so it needs nothing of its own.
    final key = (event.id, event.recordedAt.millisecondsSinceEpoch);
    final alreadyGiven = _reportedEvents.contains(key);

    // A marker that outlived a restart is proof the application never
    // confirmed the event, because nothing else could have kept it. The stored
    // time already matching says only that *the plugin* applied the deferral —
    // which it does above, before emitting — so under the manual boundary
    // "already applied" must not be read as "already delivered", or the one
    // event the opt-out exists to protect is the one it silently drops.
    //
    // Re-emitted rather than acknowledged, for the reason [_applyDrop] gives
    // for deliberately re-reporting a drop across runs: a duplicate is covered
    // by the documented `(id, recordedAt)` key, and silence is not
    // recoverable. Left alone under the default, where the plugin owns the
    // acknowledgement and this run has nothing new to say.
    final report =
        isNewDeferral || (!acknowledgeAutomatically && !alreadyGiven);

    if (report) {
      _rememberReported(key);
      _events.add(event);
      updateStream.add(alarmId);
    }

    return (handled: true, reported: report || alreadyGiven);
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
