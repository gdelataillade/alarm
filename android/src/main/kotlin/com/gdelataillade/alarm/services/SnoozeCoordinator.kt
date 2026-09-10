package com.gdelataillade.alarm.services

import android.content.Context
import com.gdelataillade.alarm.alarm.AlarmPlugin
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.models.AlarmEventCause
import com.gdelataillade.alarm.models.AlarmEventVerb
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.HostAlarmEvent
import io.flutter.Log
import java.util.Date

/**
 * Defers a ringing alarm instead of dismissing it.
 *
 * Lives outside [AlarmService] because the snooze action is normally pressed
 * with no Flutter engine and sometimes with no service either: the notification
 * is native, and the service can have been killed while its notification
 * lingered. Both entry points — the running service and [AlarmReceiver] — call
 * this same code so a snooze cannot quietly become a no-op.
 */
object SnoozeCoordinator {
    private const val TAG = "SnoozeCoordinator"

    /**
     * Defers [alarmId] by its own snooze duration.
     *
     * Ordering matters. The replacement is scheduled *before* the current ring
     * is silenced, so a failure to reschedule leaves the alarm audibly ringing
     * rather than silently cancelled — the user still gets their alarm, which
     * is the whole point of the feature.
     *
     * Returns whether the alarm was deferred.
     */
    fun snooze(context: Context, alarmId: Int): Boolean {
        if (alarmId == 0) return false

        val storage = AlarmStorage(context)
        val settings = storage.getSavedAlarms().firstOrNull { it.id == alarmId }
        if (settings == null) {
            Log.w(TAG, "Cannot snooze $alarmId: no stored alarm with that id.")
            return false
        }

        val durationMillis = settings.androidSnoozeDurationMillis
        // Both halves are required, matching the notification action and the
        // ring-activity label: an alarm that never offered snooze anywhere must
        // not be deferrable by broadcasting the action directly. AlarmReceiver
        // is exported, so this is the only thing enforcing that.
        if (!settings.canSnooze ||
            durationMillis == null ||
            settings.notificationSettings.androidSnoozeButton == null
        ) {
            // Leave it ringing rather than dismissing something the user did
            // not ask to dismiss.
            Log.w(TAG, "Cannot snooze $alarmId: snooze is not configured for it.")
            return false
        }

        val recordedAt = System.currentTimeMillis()
        val nextRingAt = recordedAt + durationMillis
        val deferred = settings.copy(dateTime = Date(nextRingAt))
        val event = HostAlarmEvent(
            alarmId = alarmId,
            verb = AlarmEventVerb.MOVED,
            cause = AlarmEventCause.SNOOZE,
            atMillis = nextRingAt,
            recordedAtMillis = recordedAt,
        )

        // Written before scheduling so a crash mid-way still leaves Dart able to
        // learn the alarm moved. Without it, Dart's own store keeps the original
        // past time and its next reconciliation pass would stop the alarm.
        storage.saveAlarmEvent(event)

        val scheduled = AlarmScheduler.schedule(context, deferred, requireDurable = true)
        if (!scheduled) {
            Log.e(TAG, "Failed to reschedule $alarmId; leaving it ringing.")
            // Undo both halves: the scheduler may already have persisted the
            // deferred time, and the marker now describes a snooze that is not
            // actually armed.
            storage.saveAlarm(settings)
            storage.clearAlarmEvent(alarmId)
            return false
        }

        // Only now is it safe to go quiet.
        val service = AlarmService.instance
        if (service != null) {
            service.silenceRing(alarmId)
        } else {
            // No foreground service owns the notification, so it has to be
            // dismissed explicitly or it lingers over a snoozed alarm.
            NotificationHandler(context).cancelNotification(alarmId)
        }

        // The marker is deliberately left for Dart to drop. A successful reply
        // here means Dart emitted the event, not that an application handler
        // has finished persisting it, so acknowledging on this side would
        // delete the only durable record while that write is still in flight.
        // See `Alarm.acknowledgeEvent`.
        AlarmPlugin.alarmTriggerApi?.alarmEvent(event.toWire()) { result ->
            if (result.isFailure) {
                Log.d(TAG, "Dart did not apply the snooze for $alarmId; keeping the marker.")
            }
        }

        Log.d(TAG, "Alarm $alarmId snoozed until $nextRingAt.")
        return true
    }
}
