// package com.gdelataillade.alarm.alarm_example

// import android.app.NotificationChannel
// import android.app.NotificationManager
// import android.app.PendingIntent
// import android.app.Service
// import android.content.Context
// import android.content.Intent
// import android.os.Build
// import android.os.IBinder
// import androidx.annotation.RequiresApi
// import androidx.core.app.NotificationCompat
// import io.flutter.Log

// class NotificationOnKillService: Service() {
//     override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
//         Log.d("NotificationOnKillService", "onStartCommand")
//         return START_STICKY
//     }

//     @RequiresApi(Build.VERSION_CODES.O)
//     override fun onTaskRemoved(rootIntent: Intent?) {
//         Log.d("NotificationOnKillService", "onTaskRemoved start")
//         try {
//             val notificationBuilder = NotificationCompat.Builder(this, "com.gdelataillade.alarm.alarm_example")
//                 .setSmallIcon(android.R.drawable.ic_notification_overlay)
//                 .setContentTitle("App was killed")
//                 .setContentText("Description")
//                 .setAutoCancel(false)
//                 .setPriority(NotificationCompat.PRIORITY_DEFAULT)
//                 .setContentIntent(PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), 0))

//                 val name = "Alarm notification service on application kill"
//                 val descriptionText = "If an alarm was set and the app is killed, a notification will show to warn the user the alarm will not ring as long as the app is killed"
//                 val importance = NotificationManager.IMPORTANCE_DEFAULT
//                 val channel = NotificationChannel("com.gdelataillade.alarm.alarm_example", name, importance).apply {
//                     description = descriptionText
//                 }
//                 // Register the channel with the system
//                 val notificationManager: NotificationManager =
//                     getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//                 notificationManager.createNotificationChannel(channel)
//                 notificationManager.notify(123, notificationBuilder.build())
//         } catch (e: Exception) {
//             Log.d("NotificationOnKillService", "Error showing notification", e)
//         }
//         Log.d("NotificationOnKillService", "onTaskRemoved end")
//         super.onTaskRemoved(rootIntent)
//     }

//     override fun onBind(intent: Intent?): IBinder? {
//         Log.d("NotificationOnKillService", "onBind")
//         return null
//     }
// }