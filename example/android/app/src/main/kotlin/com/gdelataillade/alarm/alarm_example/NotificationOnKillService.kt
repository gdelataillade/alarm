package com.gdelataillade.alarm.alarm_example

import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.Log

class NotificationOnKillService: Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("NotificationOnKillService", "onStartCommand")
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d("NotificationOnKillService", "onTaskRemoved start")
        try {
            val notificationBuilder = NotificationCompat.Builder(this, "com.gdelataillade.alarm.alarm_example")
                .setSmallIcon(android.R.drawable.ic_notification_overlay)
                .setContentTitle("App killed bro")
                .setContentText("Yoyoyoyoyoyoyoyoyoooo")
                .setAutoCancel(false)
                .setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), 0))

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(0, notificationBuilder.build())
        } catch (e: Exception) {
            Log.d("NotificationOnKillService", "Error showing notification", e)
        }
        Log.d("NotificationOnKillService", "onTaskRemoved end")
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d("NotificationOnKillService", "onBind")
        return null
    }
}