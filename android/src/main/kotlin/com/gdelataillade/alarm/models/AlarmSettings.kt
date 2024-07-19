package com.gdelataillade.alarm.models

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.util.Date
import io.flutter.Log

data class AlarmSettings(
    val id: Int,
    val dateTime: Date,
    val assetAudioPath: String,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val volume: Double?,
    val fadeDuration: Double,
    val notificationTitle: String,
    val notificationBody: String,
    val enableNotificationOnKill: Boolean,
    val androidFullScreenIntent: Boolean,
    val notificationActionSettings: NotificationActionSettings
) {
    companion object {
        fun fromJson(json: Map<String, Any>): AlarmSettings? {
            try {
                val modifiedJson = json.toMutableMap()

                // Convert dateTime from microseconds to Date
                val dateTimeMicroseconds = modifiedJson["dateTime"] as? Long
                if (dateTimeMicroseconds == null) {
                    Log.e("AlarmSettings", "dateTime is missing or not a Long")
                    return null
                }
                val dateTimeMilliseconds = dateTimeMicroseconds / 1000
                val date = Date(dateTimeMilliseconds.toLong())
                modifiedJson["dateTime"] = date
        
                // Convert notificationActionSettings from Map to NotificationActionSettings object
                val notificationActionSettingsMap = modifiedJson["notificationActionSettings"] as? Map<String, Any>
                if (notificationActionSettingsMap == null) {
                    Log.e("AlarmSettings", "notificationActionSettings is missing or not a Map")
                    return null
                }
                val notificationActionSettings = NotificationActionSettings.fromJson(notificationActionSettingsMap)
                if (notificationActionSettings == null) {
                    Log.e("AlarmSettings", "Failed to parse notificationActionSettings")
                    return null
                }
                modifiedJson["notificationActionSettings"] = notificationActionSettings
        
                // Convert the modified map to JSON string and deserialize it to an AlarmSettings object
                val gson = Gson()
                val jsonString = gson.toJson(modifiedJson)
                val result = gson.fromJson(jsonString, AlarmSettings::class.java)
                if (result == null) {
                    Log.e("AlarmSettings", "Failed to deserialize JSON to AlarmSettings")
                }
                return result
            } catch (e: Exception) {
                Log.e("AlarmSettings", "Error parsing JSON to AlarmSettings: ${e.message}")
                return null
            }
        }
    }

    fun toJson(): String {
        return Gson().toJson(this)
    }
}