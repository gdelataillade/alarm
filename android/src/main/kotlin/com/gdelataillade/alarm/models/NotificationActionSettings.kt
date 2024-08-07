package com.gdelataillade.alarm.models

import com.google.gson.Gson

data class NotificationActionSettings(
    val hasStopButton: Boolean = false,
    val stopButtonText: String = "Stop"
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