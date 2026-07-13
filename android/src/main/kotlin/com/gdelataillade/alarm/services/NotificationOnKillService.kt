package com.gdelataillade.alarm.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.Log

class NotificationOnKillService : Service() {
    companion object {
        private const val TAG = "NotificationOnKillService"
        private const val NOTIFICATION_ID = 88888
        private const val CHANNEL_ID = "com.gdelataillade.alarm.alarm_channel"

        var isRunning = false
    }

    private lateinit var title: String
    private lateinit var body: String

    override fun onCreate() {
        super.onCreate()
        isRunning = true
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        title = intent?.getStringExtra("title") ?: "Your alarms may not ring"
        body = intent?.getStringExtra("body")
            ?: "You killed the app. Please reopen so your alarms can be rescheduled."

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val notificationIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val appIconResId = packageManager.getApplicationInfo(packageName, 0).icon
            val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(appIconResId)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setContentIntent(pendingIntent)
                .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)

            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Notification channels only exist on Android 8+. Referencing the
            // class on older devices would throw a NoClassDefFoundError, which
            // the catch below would not intercept.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val name = "Alarm reliability warning"
                val descriptionText =
                    "If an alarm was set and the app is killed, a notification will warn you that the alarm might not ring on schedule."
                val importance = NotificationManager.IMPORTANCE_HIGH
                val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                    description = descriptionText
                }
                notificationManager.createNotificationChannel(channel)
            }

            notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "Error showing notification", e)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
