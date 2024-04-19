package com.gdelataillade.alarm.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.os.Build
import android.os.IBinder
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import io.flutter.Log

class NotificationOnKillService : Service() {
    private lateinit var title: String
    private lateinit var body: String
    private val NOTIFICATION_ID = 88888
    private val CHANNEL_ID = "com.gdelataillade.alarm.alarm_channel"

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        title = intent?.getStringExtra("title") ?: "Your alarms could not ring"
        body = intent?.getStringExtra("body") ?: "You killed the app. Please reopen so your alarms can be rescheduled."

        return START_STICKY
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val notificationIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

            val appIconResId = packageManager.getApplicationInfo(packageName, 0).icon
            val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(appIconResId)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setContentIntent(pendingIntent)
                .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)

            val name = "Alarm notification service on application kill"
            val descriptionText = "If an alarm was set and the app is killed, a notification will show to warn the user the alarm could not ring as long as the app is killed"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())
        } catch (e: Exception) {
            Log.e("NotificationOnKillService", "Error showing notification", e)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
