package com.gdelataillade.alarm.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.net.Uri
import android.media.AudioAttributes
import androidx.core.app.NotificationCompat

class NotificationHandler(private val context: Context) {
    companion object {
        private const val CHANNEL_ID = "alarm_service_channel"
        private const val CHANNEL_NAME = "Alarm Notification"
    }

    init {
        createNotificationChannel()
    }

   private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = Uri.parse("android.resource://${context.packageName}/${R.raw.blank}")
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                setSound(soundUri, AudioAttributes.Builder().setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            }

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }


    fun buildNotification(title: String, body: String, fullScreen: Boolean, pendingIntent: PendingIntent): Notification {
        val iconResId = context.resources.getIdentifier("ic_launcher", "mipmap", context.packageName)
        val soundUri = Uri.parse("android.resource://${context.packageName}/${R.raw.blank}")

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, 0)

        val notificationBuilder = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(iconResId)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setSound(soundUri)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (fullScreen) {
            notificationBuilder.setFullScreenIntent(pendingIntent, true)
        }

        return notificationBuilder.build()
    }
}