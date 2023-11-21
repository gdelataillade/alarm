package com.gdelataillade.alarm.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import android.app.NotificationChannel
import androidx.core.app.NotificationCompat
import android.provider.Settings

class BootCompletedReceiver : BroadcastReceiver() {
    private val NOTIFICATION_ID = 99999
    private val CHANNEL_ID = "alarm_boot_receiver"
    private val CHANNEL_NAME = "Alarm Boot Completed Notification"

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.intent.action.BOOT_COMPLETED") {
            showRescheduleNotification(context)
        }
    }

    private fun showRescheduleNotification(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, 0)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT)
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Alarm Reschedule Needed After Reboot")
            .setContentText("Please launch the app to reschedule your alarms.")
            .setSmallIcon(android.R.drawable.ic_notification_overlay)
            .setContentIntent(pendingIntent)
            .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)
            .setAutoCancel(false)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

}