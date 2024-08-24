package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.NotificationOnKillService
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.models.AlarmSettings

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.annotation.NonNull
import java.util.Date
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.Log
import org.json.JSONObject

class AlarmPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private val alarmIds: MutableList<Int> = mutableListOf()
    private var notifOnKillEnabled: Boolean = false
    private var notificationOnKillTitle: String = "Your alarms may not ring"
    private var notificationOnKillBody: String = "You killed the app. Please reopen so your alarms can be rescheduled."

    companion object {
        @JvmStatic
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/alarm")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "setAlarm" -> {
                setAlarm(call, result)
            }
            "stopAlarm" -> {
                val id = call.argument<Int>("id")
                if (id == null) {
                    result.error("INVALID_ID", "Alarm ID is null", null)
                    return
                }

                stopAlarm(id, result)
            }
            "isRinging" -> {
                val id = call.argument<Int>("id")
                val ringingAlarmIds = AlarmService.ringingAlarmIds
                val isRinging = ringingAlarmIds.contains(id)
                result.success(isRinging)
            }
            "setNotificationOnKillService" -> {
                if (call.argument<String>("title") != null && call.argument<String>("body") != null) {
                    notificationOnKillTitle = call.argument<String>("title")!!
                    notificationOnKillBody = call.argument<String>("body")!!
                }
                result.success(true)
            }
            "stopNotificationOnKillService" -> {
                stopNotificationOnKillService(context)
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun setAlarm(call: MethodCall, result: Result) {
        val alarmJsonMap = call.arguments as? Map<String, Any>
        if (alarmJsonMap != null) {
            val alarm = AlarmSettings.fromJson(alarmJsonMap)
            if (alarm != null) {
                val alarmIntent = createAlarmIntent(context, call, alarm.id)
                val delayInSeconds = (alarm.dateTime.time - System.currentTimeMillis()) / 1000

                if (delayInSeconds <= 5) {
                    handleImmediateAlarm(context, alarmIntent, delayInSeconds.toInt())
                } else {
                    handleDelayedAlarm(context, alarmIntent, delayInSeconds.toInt(), alarm.id, alarm.enableNotificationOnKill)
                }
                alarmIds.add(alarm.id)
                result.success(true)
            } else {
                result.error("INVALID_ALARM", "Failed to parse alarm JSON", null)
            }
        } else {
            result.error("INVALID_ARGUMENTS", "Invalid arguments provided for setAlarm", null)
        }
    }

    fun stopAlarm(id: Int, result: Result? = null) {
        // Check if the alarm is currently ringing
        if (AlarmService.ringingAlarmIds.contains(id)) {
            // If the alarm is ringing, stop the alarm service for this ID
            val stopIntent = Intent(context, AlarmService::class.java)
            stopIntent.action = "STOP_ALARM"
            stopIntent.putExtra("id", id)
            context.stopService(stopIntent)
        }

        // Intent to cancel the future alarm if it's set
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, 
            id, 
            alarmIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Cancel the future alarm using AlarmManager
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)

        alarmIds.remove(id)
        if (alarmIds.isEmpty() && notifOnKillEnabled) {
            stopNotificationOnKillService(context)
        }

        if (result != null) {
            result.success(true)
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

        val notificationActionSettingsMap = call.argument<Map<String, Any>>("notificationActionSettings")
        val notificationActionSettingsJson = JSONObject(notificationActionSettingsMap ?: emptyMap<String, Any>()).toString()
        intent.putExtra("notificationActionSettings", notificationActionSettingsJson)
    }

    fun handleImmediateAlarm(context: Context, intent: Intent, delayInSeconds: Int) {
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            context.sendBroadcast(intent)
        }, delayInSeconds * 1000L)
    }

    fun handleDelayedAlarm(context: Context, intent: Intent, delayInSeconds: Int, id: Int, enableNotificationOnKill: Boolean) {
        try {
            val triggerTime = System.currentTimeMillis() + delayInSeconds * 1000L
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: throw IllegalStateException("AlarmManager not available")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }

            if (enableNotificationOnKill && !notifOnKillEnabled) {
                setNotificationOnKillService(context)
            }
        } catch (e: ClassCastException) {
            Log.e("AlarmPlugin", "AlarmManager service type casting failed", e)
        } catch (e: IllegalStateException) {
            Log.e("AlarmPlugin", "AlarmManager service not available", e)
        } catch (e: Exception) {
            Log.e("AlarmPlugin", "Error in handling delayed alarm", e)
        }
    }

    fun setNotificationOnKillService(context: Context) {
        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        serviceIntent.putExtra("title", notificationOnKillTitle)
        serviceIntent.putExtra("body", notificationOnKillBody)

        context.startService(serviceIntent)
        notifOnKillEnabled = true
    }

    fun stopNotificationOnKillService(context: Context) {
        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        context.stopService(serviceIntent)
        notifOnKillEnabled = false
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}