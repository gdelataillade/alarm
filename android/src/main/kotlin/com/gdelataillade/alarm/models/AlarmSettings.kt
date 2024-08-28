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

                // Deserialize NotificationActionSettings
                val notificationActionSettingsMap = modifiedJson["notificationActionSettings"] as? Map<String, Any>
                if (notificationActionSettingsMap != null) {
                    modifiedJson["notificationActionSettings"] = NotificationActionSettings.fromJson(notificationActionSettingsMap)
                } else {
                    Log.e("AlarmSettings", "notificationActionSettings is missing or not a Map")
                    return null
                }

                // Convert the modified map to JSON string and deserialize it to an AlarmSettings object
                val jsonString = gson.toJson(modifiedJson)
                gson.fromJson(jsonString, AlarmSettings::class.java)
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