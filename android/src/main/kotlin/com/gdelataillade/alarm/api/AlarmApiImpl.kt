package com.gdelataillade.alarm.api

import com.gdelataillade.alarm.generated.AlarmApi
import com.gdelataillade.alarm.generated.AlarmSettingsWire
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.gdelataillade.alarm.alarm.AlarmPlugin
import com.gdelataillade.alarm.alarm.AlarmReceiver
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.services.NotificationOnKillService
import io.flutter.Log
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class AlarmApiImpl(private val context: Context) : AlarmApi {
    companion object {
        private const val TAG = "AlarmApiImpl"
    }

    private val alarmIds: MutableList<Int> = mutableListOf()
    private var notificationOnKillTitle: String = "Your alarms may not ring"
    private var notificationOnKillBody: String =
        "You killed the app. Please reopen so your alarms can be rescheduled."

    override fun setAlarm(alarmSettings: AlarmSettingsWire, callback: (Result<Unit>) -> Unit) {
        setAlarm(AlarmSettings.fromWire(alarmSettings))
        callback(Result.success(Unit))
    }

    override fun stopAlarm(alarmId: Long, callback: (Result<Unit>) -> Unit) {
        val id = alarmId.toInt()

        // Deliver the stop to the running service so it can clean up ringing
        // alarms and dequeue if needed. If the service isn't running, there is
        // nothing to ring/dequeue and storage cleanup below is sufficient.
        val serviceIsRunning = AlarmService.instance != null
        AlarmService.instance?.handleStopAlarmCommand(id)

        // Intent to cancel the future alarm if it's set
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Cancel the future alarm using AlarmManager
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)

        alarmIds.remove(id)
        AlarmStorage(context).unsaveAlarm(id)
        updateWarningNotificationState()

        // If the service was running it is the responsibility of the AlarmService to send the stop
        // signal to Flutter.
        if (!serviceIsRunning) {
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
        for (alarm in AlarmStorage(context).getSavedAlarms()) {
            stopAlarm(alarm.id.toLong()) {}
        }
        val alarmIdsCopy = alarmIds.toList()
        for (alarmId in alarmIdsCopy) {
            stopAlarm(alarmId.toLong()) {}
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
        notificationOnKillTitle = title
        notificationOnKillBody = body

        // Re-create if needed.
        turnOffWarningNotificationOnKill(context)
        updateWarningNotificationState()
    }

    override fun disableWarningNotificationOnKill() {
        turnOffWarningNotificationOnKill(context)
    }

    fun setAlarm(alarm: AlarmSettings) {
        if (alarmIds.contains(alarm.id)) {
            Log.w(TAG, "Stopping alarm with identical ID=${alarm.id} before scheduling a new one.")
            stopAlarm(alarm.id.toLong()) {}
        }

        val alarmIntent = createAlarmIntent(alarm)
        // Keep millisecond precision so alarms ring at the exact requested
        // time instead of up to a second early.
        val delayInMillis = alarm.dateTime.time - System.currentTimeMillis()

        alarmIds.add(alarm.id)
        AlarmStorage(context).saveAlarm(alarm)

        if (delayInMillis <= 5000L) {
            handleImmediateAlarm(alarmIntent, delayInMillis)
        } else {
            handleDelayedAlarm(alarmIntent, alarm.dateTime.time, alarm.id)
        }

        updateWarningNotificationState()
    }

    private fun createAlarmIntent(alarm: AlarmSettings): Intent {
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        alarmIntent.putExtra("id", alarm.id)
        alarmIntent.putExtra("alarmSettings", Json.encodeToString(alarm))
        return alarmIntent
    }

    private fun handleImmediateAlarm(intent: Intent, delayInMillis: Long) {
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            context.sendBroadcast(intent)
        }, delayInMillis.coerceAtLeast(0L))
    }

    private fun handleDelayedAlarm(
        intent: Intent,
        triggerTimeMillis: Long,
        id: Int,
    ) {
        try {
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: throw IllegalStateException("AlarmManager not available")

            setExactAlarm(alarmManager, triggerTimeMillis, pendingIntent)
        } catch (e: ClassCastException) {
            Log.e(TAG, "AlarmManager service type casting failed", e)
        } catch (e: IllegalStateException) {
            Log.e(TAG, "AlarmManager service not available", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error in handling delayed alarm", e)
        }
    }

    private fun setExactAlarm(
        alarmManager: AlarmManager,
        triggerTimeMillis: Long,
        pendingIntent: PendingIntent,
    ) {
        // On Android 12+ the user can revoke the exact alarm permission at any
        // time. Fall back to an inexact alarm instead of silently scheduling
        // nothing: the alarm may ring a few minutes late, but it will ring.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            Log.w(
                TAG,
                "SCHEDULE_EXACT_ALARM permission not granted. Falling back to an " +
                    "inexact alarm, which may ring late. Ask the user to grant the " +
                    "'Alarms & reminders' permission for exact scheduling."
            )
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTimeMillis,
                pendingIntent
            )
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
            }
        } catch (e: SecurityException) {
            // Defensive: the permission state changed between the check above
            // and the call, or an OEM enforces it on older API levels.
            Log.e(TAG, "Exact alarm scheduling rejected; falling back to inexact alarm", e)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
            }
        }
    }

    private fun updateWarningNotificationState() {
        if (AlarmStorage(context).getSavedAlarms().any { it.warningNotificationOnKill } ) {
            turnOnWarningNotificationOnKill(context)
        } else {
            turnOffWarningNotificationOnKill(context)
        }
    }

    private fun turnOnWarningNotificationOnKill(context: Context) {
        if (NotificationOnKillService.isRunning) {
            Log.d(TAG, "Warning notification is already turned on.")
            return
        }

        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        serviceIntent.putExtra("title", notificationOnKillTitle)
        serviceIntent.putExtra("body", notificationOnKillBody)

        context.startService(serviceIntent)
        Log.d(TAG, "Warning notification turned on.")
    }

    private fun turnOffWarningNotificationOnKill(context: Context) {
        if (!NotificationOnKillService.isRunning) {
            Log.d(TAG, "Warning notification is already turned off.")
            return
        }

        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        context.stopService(serviceIntent)
        Log.d(TAG, "Warning notification turned off.")
    }
}
