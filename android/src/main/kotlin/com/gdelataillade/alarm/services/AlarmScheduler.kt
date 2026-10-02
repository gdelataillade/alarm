package com.gdelataillade.alarm.services

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.gdelataillade.alarm.alarm.AlarmReceiver
import com.gdelataillade.alarm.models.AlarmSettings
import io.flutter.Log
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * Persists an alarm and arms the platform to deliver it.
 *
 * Deliberately context-only and free of any stop path: it never touches
 * `AlarmApiImpl.alarmIds`, never calls `AlarmApiImpl.stopAlarm`,
 * `AlarmService.handleStopAlarmCommand` or `AlarmService.unsaveAlarm`, and never
 * reports anything to Flutter. Those all announce a *stop*, which is exactly
 * wrong for a snooze — the alarm is still owed. Callers that do want the
 * replace-then-reschedule behaviour layer it on top themselves.
 */
object AlarmScheduler {
    private const val TAG = "AlarmScheduler"

    /**
     * Delay at or below which the platform is armed with a plain
     * `Handler.postDelayed` instead of `AlarmManager`.
     *
     * That fallback lives only as long as the process and cannot be cancelled
     * through `AlarmManager.cancel`, so it is unusable for anything that has to
     * survive termination.
     */
    const val IMMEDIATE_THRESHOLD_MILLIS = 5000L

    enum class ArmMode { ALARM_CLOCK, EXACT_WHILE_IDLE, EXACT, INEXACT_WHILE_IDLE }

    /**
     * Which `AlarmManager` call arms an alarm. Without the exact alarm permission
     * every mode, alarm clocks included, falls back to an inexact alarm.
     */
    internal fun armMode(sdkInt: Int, canScheduleExact: Boolean, alarmClock: Boolean): ArmMode =
        when {
            sdkInt >= Build.VERSION_CODES.S && !canScheduleExact -> ArmMode.INEXACT_WHILE_IDLE
            alarmClock -> ArmMode.ALARM_CLOCK
            sdkInt >= Build.VERSION_CODES.M -> ArmMode.EXACT_WHILE_IDLE
            else -> ArmMode.EXACT
        }

    /**
     * Saves [alarm] and arms its delivery.
     *
     * When [requireDurable] is set, refuses rather than falling back to the
     * in-process timer, so a caller that needs the alarm to survive process
     * death finds out instead of silently getting a weaker guarantee.
     *
     * Returns whether the alarm is now both stored and armed. An exact-alarm
     * permission downgrade to an inexact alarm still counts as success: the
     * alarm may ring late, but it will ring.
     */
    fun schedule(
        context: Context,
        alarm: AlarmSettings,
        requireDurable: Boolean = false,
    ): Boolean {
        val delayInMillis = alarm.dateTime.time - System.currentTimeMillis()

        if (delayInMillis <= IMMEDIATE_THRESHOLD_MILLIS && requireDurable) {
            Log.e(
                TAG,
                "Refusing to schedule alarm ${alarm.id} durably: it is due in " +
                    "${delayInMillis}ms, which is below the ${IMMEDIATE_THRESHOLD_MILLIS}ms " +
                    "AlarmManager threshold."
            )
            return false
        }

        AlarmStorage(context).saveAlarm(alarm)

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("id", alarm.id)
            putExtra("alarmSettings", Json.encodeToString(alarm))
        }

        val armed = if (delayInMillis <= IMMEDIATE_THRESHOLD_MILLIS) {
            Handler(Looper.getMainLooper()).postDelayed(
                { context.sendBroadcast(intent) },
                delayInMillis.coerceAtLeast(0L)
            )
            true
        } else {
            armAlarmManager(context, intent, alarm.dateTime.time, alarm.id, alarm.androidAlarmClock)
        }

        // Every path that adds a pending alarm has to leave the kill warning
        // consistent with it, including the snooze path, which reaches here
        // without going through the plugin.
        WarningNotificationState.refresh(context)

        return armed
    }

    /**
     * Arms `AlarmManager` for [triggerTimeMillis].
     *
     * Unlike the code this replaced, a genuine failure is reported rather than
     * logged and swallowed — a caller that has silenced a ringing alarm on the
     * strength of a successful reschedule has to be able to tell.
     */
    private fun armAlarmManager(
        context: Context,
        intent: Intent,
        triggerTimeMillis: Long,
        id: Int,
        alarmClock: Boolean,
    ): Boolean {
        return try {
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            if (alarmManager == null) {
                Log.e(TAG, "Cannot arm alarm $id: AlarmManager is not available.")
                return false
            }

            setExactAlarm(context, alarmManager, triggerTimeMillis, pendingIntent, alarmClock)
            true
        } catch (e: IllegalStateException) {
            // Reporting this as "service not available" was misleading: a missing
            // service is handled above, and what reaches here is AlarmManager
            // refusing the alarm — documented for an app that already holds the
            // maximum number of scheduled alarms (500).
            Log.e(
                TAG,
                "AlarmManager refused to arm alarm $id. The likely cause is this " +
                    "app having reached the per-app limit on scheduled alarms.",
                e
            )
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error while arming alarm $id", e)
            false
        }
    }

    private fun setExactAlarm(
        context: Context,
        alarmManager: AlarmManager,
        triggerTimeMillis: Long,
        pendingIntent: PendingIntent,
        alarmClock: Boolean,
    ) {
        val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
        val mode = armMode(Build.VERSION.SDK_INT, canScheduleExact, alarmClock)

        try {
            when (mode) {
                ArmMode.ALARM_CLOCK -> alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(triggerTimeMillis, showIntent(context)),
                    pendingIntent
                )
                ArmMode.EXACT_WHILE_IDLE -> alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
                ArmMode.EXACT -> alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
                ArmMode.INEXACT_WHILE_IDLE -> {
                    // On Android 12+ the user can revoke the exact alarm permission at
                    // any time. An inexact alarm may ring a few minutes late, but it rings.
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
                }
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

    /** What tapping the next alarm in the system UI opens: the app, or nothing if it has no launcher. */
    private fun showIntent(context: Context): PendingIntent? {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        return PendingIntent.getActivity(context, 0, launch, PendingIntent.FLAG_IMMUTABLE)
    }
}
