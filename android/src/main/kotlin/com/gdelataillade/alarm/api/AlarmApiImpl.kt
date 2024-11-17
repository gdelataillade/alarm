package com.gdelataillade.alarm.api

import AlarmApi
import AlarmSettingsWire
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.gdelataillade.alarm.alarm.AlarmReceiver
import com.gdelataillade.alarm.alarm.AlarmService
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.services.NotificationOnKillService
import com.google.gson.Gson
import io.flutter.Log

class AlarmApiImpl(private val context: Context) : AlarmApi {
    private val alarmIds: MutableList<Int> = mutableListOf()
    private var notifyOnKillEnabled: Boolean = false
    private var notificationOnKillTitle: String = "Your alarms may not ring"
    private var notificationOnKillBody: String =
        "You killed the app. Please reopen so your alarms can be rescheduled."

    override fun setAlarm(alarmSettings: AlarmSettingsWire) {
        setAlarm(AlarmSettings.fromWire(alarmSettings))
    }

    override fun stopAlarm(alarmId: Long) {
        val id = alarmId.toInt()
        if (AlarmService.ringingAlarmIds.contains(id)) {
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
        if (alarmIds.isEmpty() && notifyOnKillEnabled) {
            disableWarningNotificationOnKill(context)
        }
    }

    override fun isRinging(alarmId: Long?): Boolean {
        val ringingAlarmIds = AlarmService.ringingAlarmIds
        if (alarmId == null) {
            return ringingAlarmIds.isNotEmpty()
        }
        return ringingAlarmIds.contains(alarmId.toInt())
    }

    override fun setWarningNotificationOnKill(title: String, body: String) {
        notificationOnKillTitle = title
        notificationOnKillBody = body
    }

    override fun disableWarningNotificationOnKill() {
        disableWarningNotificationOnKill(context)
    }

    fun setAlarm(alarm: AlarmSettings) {
        val alarmIntent = createAlarmIntent(alarm)
        val delayInSeconds = (alarm.dateTime.time - System.currentTimeMillis()) / 1000

        if (delayInSeconds <= 5) {
            handleImmediateAlarm(alarmIntent, delayInSeconds.toInt())
        } else {
            handleDelayedAlarm(
                alarmIntent,
                delayInSeconds.toInt(),
                alarm.id,
                alarm.warningNotificationOnKill
            )
        }
        alarmIds.add(alarm.id)
    }

    private fun createAlarmIntent(alarm: AlarmSettings): Intent {
        val alarmIntent = Intent(context, AlarmReceiver::class.java)
        setIntentExtras(alarmIntent, alarm)
        return alarmIntent
    }

    private fun setIntentExtras(intent: Intent, alarm: AlarmSettings) {
        intent.putExtra("id", alarm.id)
        intent.putExtra("assetAudioPath", alarm.assetAudioPath)
        intent.putExtra("loopAudio", alarm.loopAudio)
        intent.putExtra("vibrate", alarm.vibrate)
        intent.putExtra("volume", alarm.volume)
        intent.putExtra("volumeEnforced", alarm.volumeEnforced)
        intent.putExtra("fadeDuration", alarm.fadeDuration)
        intent.putExtra("fullScreenIntent", alarm.androidFullScreenIntent)

        val notificationSettingsMap = alarm.notificationSettings
        val gson = Gson()
        val notificationSettingsJson = gson.toJson(notificationSettingsMap)
        intent.putExtra("notificationSettings", notificationSettingsJson)
    }

    private fun handleImmediateAlarm(intent: Intent, delayInSeconds: Int) {
        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            context.sendBroadcast(intent)
        }, delayInSeconds * 1000L)
    }

    private fun handleDelayedAlarm(
        intent: Intent,
        delayInSeconds: Int,
        id: Int,
        warningNotificationOnKill: Boolean
    ) {
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
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }

            if (warningNotificationOnKill && !notifyOnKillEnabled) {
                setWarningNotificationOnKill(context)
            }
        } catch (e: ClassCastException) {
            Log.e("AlarmPlugin", "AlarmManager service type casting failed", e)
        } catch (e: IllegalStateException) {
            Log.e("AlarmPlugin", "AlarmManager service not available", e)
        } catch (e: Exception) {
            Log.e("AlarmPlugin", "Error in handling delayed alarm", e)
        }
    }

    private fun setWarningNotificationOnKill(context: Context) {
        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        serviceIntent.putExtra("title", notificationOnKillTitle)
        serviceIntent.putExtra("body", notificationOnKillBody)

        context.startService(serviceIntent)
        notifyOnKillEnabled = true
    }

    private fun disableWarningNotificationOnKill(context: Context) {
        val serviceIntent = Intent(context, NotificationOnKillService::class.java)
        context.stopService(serviceIntent)
        notifyOnKillEnabled = false
    }
}
