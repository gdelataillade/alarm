package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.NotificationOnKillService

import android.os.Build
import android.os.Handler
import android.os.Looper
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
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.Log

import android.content.ComponentName
import android.content.pm.PackageManager

class AlarmPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel : MethodChannel

    companion object {
        @JvmStatic
        lateinit var binaryMessenger: BinaryMessenger
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/alarm")
        channel.setMethodCallHandler(this)
        binaryMessenger = flutterPluginBinding.binaryMessenger
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "setAlarm" -> {
                val id = call.argument<Int>("id")!!
                val delayInSeconds = call.argument<Int>("delayInSeconds")!!

                val alarmIntent = createAlarmIntent(context, call, id)

                if (delayInSeconds <= 5) {
                    handleImmediateAlarm(context, alarmIntent, delayInSeconds)
                } else {
                    handleDelayedAlarm(context, alarmIntent, delayInSeconds, id)
                }

                result.success(true)
            }
            "stopAlarm" -> {
                val id = call.argument<Int>("id")

                // Intent to stop the alarm
                val stopIntent = Intent(context, AlarmService::class.java)
                stopIntent.action = "STOP_ALARM"
                stopIntent.putExtra("id", id)
                context.startService(stopIntent)

                // Intent to cancel the future alarm if it's set
                val alarmIntent = Intent(context, AlarmReceiver::class.java)
                val pendingIntent = PendingIntent.getBroadcast(context, id!!, alarmIntent, PendingIntent.FLAG_UPDATE_CURRENT)

                // Cancel the future alarm using AlarmManager
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(pendingIntent)

                result.success(true)
            }
            "isRinging" -> {
                val id = call.argument<Int>("id")
                val ringingAlarmIds = AlarmService.ringingAlarmIds
                val isRinging = ringingAlarmIds.contains(id)
                result.success(isRinging)
            }
            "setNotificationOnKillService" -> {
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")

                val serviceIntent = Intent(context, NotificationOnKillService::class.java)
                serviceIntent.putExtra("title", title)
                serviceIntent.putExtra("body", body)

                context.startService(serviceIntent)

                result.success(true)
            }
            "stopNotificationOnKillService" -> {
                val serviceIntent = Intent(context, NotificationOnKillService::class.java)
                context.stopService(serviceIntent)
                result.success(true)
            }
            "setNotificationOnReboot" -> {
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                enableBootCompletedReceiver(context)
                result.success(true)
            }
            "stopNotificationOnReboot" -> {
                disableBootCompletedReceiver(context)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun createAlarmIntent(context: Context, call: MethodCall, id: Int?): Intent {
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        setIntentExtras(alarmIntent, call, id)
        return alarmIntent
    }

    fun setIntentExtras(intent: Intent, call: MethodCall, id: Int?) {
        intent.putExtra("id", id)
        intent.putExtra("assetAudioPath", call.argument<String>("assetAudioPath"))
        intent.putExtra("loopAudio", call.argument<Boolean>("loopAudio"))
        intent.putExtra("vibrate", call.argument<Boolean>("vibrate"))
        intent.putExtra("volume", call.argument<Boolean>("volume"))
        intent.putExtra("fadeDuration", call.argument<Double>("fadeDuration"))
        intent.putExtra("notificationTitle", call.argument<String>("notificationTitle"))
        intent.putExtra("notificationBody", call.argument<String>("notificationBody"))
        intent.putExtra("fullScreenIntent", call.argument<Boolean>("fullScreenIntent"))
    }

    fun handleImmediateAlarm(context: Context, intent: Intent, delayInSeconds: Int) {
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            context.sendBroadcast(intent)
        }, delayInSeconds * 1000L)
    }

    fun handleDelayedAlarm(context: Context, intent: Intent, delayInSeconds: Int, id: Int) {
        val triggerTime = System.currentTimeMillis() + delayInSeconds * 1000
        val pendingIntent = PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
    }

    fun enableBootCompletedReceiver(context: Context) {
        val receiver = ComponentName(context, BootCompletedReceiver::class.java)
        val packageManager = context.packageManager

        packageManager.setComponentEnabledSetting(
            receiver,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    fun disableBootCompletedReceiver(context: Context) {
        val receiver = ComponentName(context, BootCompletedReceiver::class.java)
        val packageManager = context.packageManager

        packageManager.setComponentEnabledSetting(
            receiver,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}