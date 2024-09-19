package com.gdelataillade.alarm.models

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.util.Date
import io.flutter.Log

data class AlarmSettings(
    val id: Int,
    val dateTime: Date,
    val assetAudioPath: String,
    val notificationSettings: NotificationSettings,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val volume: Double?,
    val fadeDuration: Double,
    val warningNotificationOnKill: Boolean,
    val androidFullScreenIntent: Boolean
) {
    companion object {
        fun fromJson(json: Map<String, Any>): AlarmSettings? {
            return try {
                val gson = Gson()
        
                // Convert dateTime from microseconds to Date
                val modifiedJson = json.toMutableMap()
                val dateTimeMicroseconds = modifiedJson["dateTime"] as? Long
                if (dateTimeMicroseconds != null) {
                    val dateTimeMilliseconds = dateTimeMicroseconds / 1000
                    modifiedJson["dateTime"] = Date(dateTimeMilliseconds)
                } else {
                    Log.e("AlarmSettings", "dateTime is missing or not a Long")
                    return null
                }
        
                // Deserialize NotificationSettings
                val notificationSettingsMap = modifiedJson["notificationSettings"] as? Map<*, *>
                if (notificationSettingsMap != null) {
                    modifiedJson["notificationSettings"] = NotificationSettings.fromJson(notificationSettingsMap as Map<String, Any>)
                } else {
                    Log.e("AlarmSettings", "-> notificationSettings is missing or not a Map")
                    return null
                }
        
                // Convert the modified map to JSON string and deserialize it to an AlarmSettings object
                val jsonString = gson.toJson(modifiedJson)
                val alarmSettings = gson.fromJson(jsonString, AlarmSettings::class.java)
                alarmSettings
            } catch (e: Exception) {
                Log.e("AlarmSettings", "Error parsing JSON to AlarmSettings: ${e.message}")
                null
            }
        }
    }

    fun toJson(): String {
        return Gson().toJson(this)
    }
}