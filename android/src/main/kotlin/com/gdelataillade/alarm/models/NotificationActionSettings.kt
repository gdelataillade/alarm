package com.gdelataillade.alarm.models

import com.google.gson.Gson

data class NotificationActionSettings(
    val hasStopButton: Boolean = false,
    val hasSnoozeButton: Boolean = false,
    val stopButtonText: String = "Stop",
    val snoozeButtonText: String = "Snooze",
    val snoozeDurationInSeconds: Int = 9 * 60
) {
    companion object {
        fun fromJson(json: Map<String, Any>): NotificationActionSettings {
            val gson = Gson()
            val jsonString = gson.toJson(json)
            return gson.fromJson(jsonString, NotificationActionSettings::class.java)
        }
    }

    fun toJson(): String {
        return Gson().toJson(this)
    }
}