package com.gdelataillade.alarm.services

import android.annotation.SuppressLint
import com.gdelataillade.alarm.models.NotificationSettings
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.gdelataillade.alarm.alarm.AlarmReceiver

class NotificationHandler(private val context: Context) {
    companion object {
        private const val CHANNEL_ID = "alarm_plugin_channel"
        private const val CHANNEL_NAME = "Alarm Notification"
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null)
            }

            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    // Dismisses the alarm notification when no foreground service owns it
    // (a live service removes it via stopForeground(STOP_FOREGROUND_REMOVE)).
    fun cancelNotification(id: Int) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id)
    }

    /**
     * Delete intent that puts the notification for [alarmId] back.
     *
     * Shares the alarm id as request code with the stop and snooze intents, which
     * is safe because `PendingIntent` identity includes the action: only the
     * extras are ignored.
     */
    private fun restorePendingIntent(alarmId: Int): PendingIntent {
        val restoreIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_RESTORE
            putExtra("id", alarmId)
        }
        return PendingIntent.getBroadcast(
            context,
            alarmId,
            restoreIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun buildNotification(
        notificationSettings: NotificationSettings,
        fullScreen: Boolean,
        pendingIntent: PendingIntent,
        alarmId: Int,
        canSnooze: Boolean = false
    ): Notification {
        val iconResId = iconResId(notificationSettings)

        val stopIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_ALARM_STOP
            putExtra("id", alarmId)
        }
        // Use the alarm id as request code so each alarm gets its own pending
        // intent; with a shared request code the stop button of one alarm
        // would stop whichever alarm was scheduled last.
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            alarmId,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconResId)
            .setContentTitle(notificationSettings.title)
            .setContentText(notificationSettings.body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setSound(null)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        // setOngoing(true) above no longer pins the notification: since Android 13 a
        // foreground service notification can be swiped away while the device is
        // unlocked. The delete intent is the only signal Android gives for that
        // swipe, so it is what decides what the swipe means.
        //
        // Opting out has to *restore* rather than ignore. Ignoring it leaves the
        // alarm sounding with its only on-screen control gone, which is worse than
        // the stray swipe the opt-out exists to prevent; re-posting extends to an
        // unlocked device what the platform already guarantees on a locked one.
        notificationBuilder.setDeleteIntent(
            if (notificationSettings.androidStopAlarmOnDismiss) {
                stopPendingIntent
            } else {
                restorePendingIntent(alarmId)
            }
        )

        if (fullScreen) {
            notificationBuilder.setFullScreenIntent(pendingIntent, true)
        }

        notificationSettings.let {
            if (it.stopButton != null) {
                notificationBuilder.addAction(0, it.stopButton, stopPendingIntent)
            }

            // A label without a duration describes an action the platform
            // cannot perform, so both are required before it is offered.
            if (it.androidSnoozeButton != null && canSnooze) {
                val snoozeIntent = Intent(context, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_ALARM_SNOOZE
                    putExtra("id", alarmId)
                }
                val snoozePendingIntent = PendingIntent.getBroadcast(
                    context,
                    alarmId,
                    snoozeIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                notificationBuilder.addAction(0, it.androidSnoozeButton, snoozePendingIntent)
            }

            if (it.iconColor != null) {
                notificationBuilder.setColor(it.iconColor)
            }
        }

        return notificationBuilder.build()
    }

    /**
     * What a non-looping alarm leaves behind with `keepNotificationAfterAlarmEnds`: the
     * alarm is over, so no actions, nothing ongoing, and silent so it does not alert again.
     */
    fun postEndedNotification(notificationSettings: NotificationSettings, alarmId: Int) {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconResId(notificationSettings))
            .setContentTitle(notificationSettings.title)
            .setContentText(notificationSettings.body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        if (launch != null) {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    context,
                    alarmId,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        notificationSettings.iconColor?.let { builder.setColor(it) }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(alarmId, builder.build())
    }

    // We need to use [Resources.getIdentifier] because resources are registered by Flutter.
    @SuppressLint("DiscouragedApi")
    private fun iconResId(notificationSettings: NotificationSettings): Int {
        val defaultIconResId =
            context.packageManager.getApplicationInfo(context.packageName, 0).icon
        val icon = notificationSettings.icon ?: return defaultIconResId
        val resId = context.resources.getIdentifier(icon, "drawable", context.packageName)
        return if (resId != 0) resId else defaultIconResId
    }
}
