package com.gdelataillade.alarm.api

import com.gdelataillade.alarm.generated.AlarmApi
import com.gdelataillade.alarm.generated.AlarmErrorCode
import com.gdelataillade.alarm.generated.AlarmEventWire
import com.gdelataillade.alarm.generated.AlarmSettingsWire
import com.gdelataillade.alarm.generated.FlutterError
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.gdelataillade.alarm.alarm.AlarmPlugin
import com.gdelataillade.alarm.alarm.AlarmReceiver
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.services.AlarmScheduler
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.services.NotificationHandler
import com.gdelataillade.alarm.services.WarningNotificationState
import io.flutter.Log

class AlarmApiImpl(private val context: Context) : AlarmApi {
    companion object {
        private const val TAG = "AlarmApiImpl"

        internal fun idsToStopAll(
            ringing: List<Int>,
            stored: List<Int>,
            tracked: Set<Int>,
        ): List<Int> = (ringing + stored + tracked).distinct()
    }

    // A set, so the replace path in [setAlarm] cannot add a second copy of an id it
    // already holds: List.remove drops only the first, and stopAll would then stop the
    // same alarm once per copy.
    private val alarmIds: MutableSet<Int> = mutableSetOf()

    override fun setAlarm(alarmSettings: AlarmSettingsWire, callback: (Result<Unit>) -> Unit) {
        val alarm = AlarmSettings.fromWire(alarmSettings)
        if (setAlarm(alarm)) {
            callback(Result.success(Unit))
            return
        }

        // AlarmScheduler saves before it arms, so a failure leaves a stored alarm the
        // platform never armed. Reporting that as success is what made the failure
        // unobservable: Alarm.set() returned true, getAlarms() kept listing the alarm,
        // and nothing rang.
        //
        // Dart's own failure path stops the alarm moments after this reply, which is
        // what really cleans up, but the process can die in between — and a phantom
        // that survives in storage is re-armed by BootReceiver after the next reboot,
        // ringing an alarm the app believes does not exist. So undo the halves that
        // landed here too.
        //
        // Each step is isolated on purpose. This is the failure path, so one cleanup
        // throwing must not take the others down with it, and the reply has to be
        // reached whatever happens or Dart waits on a channel error instead of the
        // real cause.
        alarmIds.remove(alarm.id)
        runCatching { cancelPendingBroadcast(alarm.id) }
            .onFailure { Log.e(TAG, "Failed to cancel the pending broadcast for ${alarm.id}", it) }
        runCatching { AlarmStorage(context).unsaveAlarm(alarm.id) }
            .onFailure { Log.e(TAG, "Failed to unsave ${alarm.id} after a failed arm", it) }
        runCatching { WarningNotificationState.refresh(context) }
            .onFailure { Log.e(TAG, "Failed to refresh the kill-warning state", it) }

        callback(
            Result.failure(
                FlutterError(
                    // The raw int, not the name: Dart maps the code back with
                    // int.tryParse, so a name would arrive as AlarmErrorCode.unknown.
                    AlarmErrorCode.PLUGIN_INTERNAL.raw.toString(),
                    "Alarm ${alarm.id} could not be armed. " +
                        "See the AlarmScheduler logs for the cause.",
                    null
                )
            )
        )
    }

    override fun stopAlarm(alarmId: Long, callback: (Result<Unit>) -> Unit) {
        val id = alarmId.toInt()

        // Deliver the stop to the running service so it can clean up ringing
        // alarms and dequeue if needed. If the service isn't running, there is
        // nothing to ring/dequeue and storage cleanup below is sufficient.
        val serviceIsRunning = AlarmService.instance != null
        AlarmService.instance?.handleStopAlarmCommand(id)

        // Cancel the future alarm if it's set
        cancelPendingBroadcast(id)

        alarmIds.remove(id)
        AlarmStorage(context).unsaveAlarm(id)
        WarningNotificationState.refresh(context)

        // If the service was running it is the responsibility of the AlarmService to send the stop
        // signal to Flutter.
        if (!serviceIsRunning) {
            // No foreground service owns the notification here, so a lingering
            // one must be cancelled explicitly.
            NotificationHandler(context).cancelNotification(id)
            // Notify the plugin about the alarm being stopped.
            AlarmPlugin.alarmTriggerApi?.alarmStopped(id.toLong()) {
                if (it.isSuccess) {
                    Log.d(
                        TAG,
                        "Alarm stopped notification for $id was processed successfully by Flutter."
                    )
                } else {
                    Log.d(TAG, "Alarm stopped notification for $id encountered error in Flutter.")
                }
            }
        }
        callback(Result.success(Unit))
    }

    override fun stopAll(callback: (Result<Unit>) -> Unit) {
        val ids = idsToStopAll(
            ringing = AlarmService.ringingAlarmIds,
            stored = AlarmStorage(context).getSavedAlarms().map { it.id },
            tracked = alarmIds,
        )
        for (id in ids) {
            runCatching { stopAlarm(id.toLong()) {} }
                .onFailure { Log.e(TAG, "Failed to stop alarm $id during stopAll", it) }
        }
        callback(Result.success(Unit))
    }

    override fun isRinging(alarmId: Long?): Boolean {
        val ringingAlarmIds = AlarmService.ringingAlarmIds
        if (alarmId == null) {
            return ringingAlarmIds.isNotEmpty()
        }
        return ringingAlarmIds.contains(alarmId.toInt())
    }

    override fun setWarningNotificationOnKill(title: String, body: String) {
        WarningNotificationState.setText(context, title, body)

        // Re-create so the new text takes effect if it is already showing.
        WarningNotificationState.disable(context)
        WarningNotificationState.refresh(context)
    }

    override fun disableWarningNotificationOnKill() {
        WarningNotificationState.disable(context)
    }

    override fun getPendingAlarmEvents(callback: (Result<List<AlarmEventWire>>) -> Unit) {
        val events = AlarmStorage(context).getPendingAlarmEvents()
        callback(Result.success(events.map { it.toWire() }))
    }

    override fun acknowledgeAlarmEvent(
        alarmId: Long,
        recordedAtMillis: Long,
        callback: (Result<Unit>) -> Unit,
    ) {
        AlarmStorage(context).acknowledgeAlarmEvent(alarmId.toInt(), recordedAtMillis)
        callback(Result.success(Unit))
    }

    /**
     * Arms [alarm] and records it as one of ours.
     *
     * Returns whether the alarm is now both stored and armed. Deliberately rolls back
     * nothing of its own: what a failure *means* depends on the caller, which is the
     * same reason [AlarmScheduler.schedule] leaves it alone. The Pigeon path above
     * unsaves, because Dart is waiting for an answer and a stored-but-unarmed alarm
     * would be reported as scheduled forever. BootReceiver must not, because native
     * storage is the only record it re-arms from.
     */
    fun setAlarm(alarm: AlarmSettings): Boolean {
        if (alarmIds.contains(alarm.id)) {
            Log.w(TAG, "Replacing alarm with identical ID=${alarm.id}.")
            clearForReplace(alarm.id)
        }

        alarmIds.add(alarm.id)

        // Persisting and arming live in AlarmScheduler so the snooze path can
        // reuse them without also inheriting the stop-and-replace preamble
        // above, which would report the deferral to Flutter as a stop.
        return AlarmScheduler.schedule(context, alarm)
    }

    /**
     * Tears [id] down for a same-id replace, deliberately without telling Flutter: an
     * `alarmStopped` would race the reply to `Alarm.set`, and Dart's handler unsaves
     * unconditionally, so it would delete the alarm that was just saved.
     */
    private fun clearForReplace(id: Int) {
        AlarmService.instance?.silenceRing(id)

        // FLAG_UPDATE_CURRENT: an entry left armed fires at the old time with the new settings.
        runCatching { cancelPendingBroadcast(id) }
            .onFailure { Log.e(TAG, "Failed to cancel the pending broadcast for $id", it) }

        // Also the only thing that clears a pending MOVED marker. schedule() re-saves.
        AlarmStorage(context).unsaveAlarm(id)
    }

    /**
     * Cancels any `AlarmManager` entry armed for [id].
     *
     * Rebuilding the same broadcast intent is how `AlarmManager` identifies the entry
     * to drop: `PendingIntent` equality ignores extras, so the plain intent here
     * matches whatever [AlarmScheduler] armed.
     *
     * Never throws. Both callers reach this while cleaning up — including the case
     * where the alarm service itself is unavailable, which is one of the failures the
     * rollback exists for — so a cancel that cannot happen must not take the rest of
     * the cleanup, or the reply to Dart, down with it.
     */
    private fun cancelPendingBroadcast(id: Int) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager == null) {
                Log.e(TAG, "Cannot cancel alarm $id: AlarmManager is not available.")
                return
            }

            val alarmIntent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error while cancelling the pending broadcast for alarm $id", e)
        }
    }
}
