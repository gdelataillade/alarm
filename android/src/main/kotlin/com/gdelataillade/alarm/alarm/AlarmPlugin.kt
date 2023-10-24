package com.gdelataillade.alarm.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.Log

class AlarmPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel : MethodChannel

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/notifOnAppKill")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "setAlarm" -> {
                val alarmIntent = Intent(context, AlarmReceiver::class.java)

                val delayInSeconds = call.argument<Int>("delayInSeconds")

                alarmIntent.putExtra("id", call.argument<Int>("id"))
                alarmIntent.putExtra("assetAudioPath", call.argument<String>("assetAudioPath"))
                alarmIntent.putExtra("loopAudio", call.argument<Boolean>("loopAudio"))
                alarmIntent.putExtra("vibrate", call.argument<Boolean>("vibrate"))
                alarmIntent.putExtra("volume", call.argument<Boolean>("volume"))
                alarmIntent.putExtra("fadeDuration", call.argument<Double>("fadeDuration"))
                alarmIntent.putExtra("notificationTitle", call.argument<String>("notificationTitle"))
                alarmIntent.putExtra("notificationBody", call.argument<String>("notificationBody"))

                val triggerAtMillis = System.currentTimeMillis() + delayInSeconds!! * 1000
                val pendingIntent = PendingIntent.getBroadcast(context, 0, alarmIntent, 0)
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

                Log.d("AlarmService", "triggerAtMillis: $triggerAtMillis")
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)

                result.success(true)
            }
            "setNotificationOnKillService" -> {
                val title = call.argument<String>("title")
                val description = call.argument<String>("description")
                val body = call.argument<String>("body")

                val serviceIntent = Intent(context, NotificationOnKillService::class.java)
                serviceIntent.putExtra("title", title)
                serviceIntent.putExtra("description", description)

                context.startService(serviceIntent)
                result.success(true)
            }
            "stopNotificationOnKillService" -> {
                val serviceIntent = Intent(context, NotificationOnKillService::class.java)
                context.stopService(serviceIntent)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}