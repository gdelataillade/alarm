package com.gdelataillade.alarm.services

import com.gdelataillade.alarm.models.AlarmSettings

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializer
import java.util.Date
import io.flutter.Log

class AlarmStorage(context: Context) {
    companion object {
        private const val PREFIX = "flutter.__alarm_id__"
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    // TODO(gdelataillade): Ensure this function is called or remove it.
    fun saveAlarm(alarmSettings: AlarmSettings) {
        val key = "$PREFIX${alarmSettings.id}"
        val editor = prefs.edit()
        editor.putString(key, alarmSettings.toJson())
        editor.apply()
    }

    fun unsaveAlarm(id: Int) {
        val key = "$PREFIX$id"
        val editor = prefs.edit()
        editor.remove(key)
        editor.apply()
    }

    fun getSavedAlarms(): List<AlarmSettings> {
        val alarms = mutableListOf<AlarmSettings>()
        prefs.all.forEach { (key, value) ->
            if (key.startsWith(PREFIX) && value is String) {
                try {
                    val alarm = AlarmSettings.fromJson(value)
                    if (alarm != null) {
                        alarms.add(alarm)
                    } else {
                        Log.e("AlarmStorage", "Alarm for key $key could not be deserialized")
                    }
                } catch (e: Exception) {
                    Log.e("AlarmStorage", "Error parsing alarm settings for key $key: ${e.message}")
                }
            } else {
                Log.w("AlarmStorage", "Skipping non-alarm preference with key: $key")
            }
        }
        return alarms
    }
}