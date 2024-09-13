package com.gdelataillade.alarm.models

import com.google.gson.Gson

data class NotificationSettings(
    val title: String,
    val body: String,
    val stopButton: String? = null,
    val icon: String? = null
) {
    companion object {
        fun fromJson(json: Map<String, Any>): NotificationSettings {
            val gson = Gson()
            val jsonString = gson.toJson(json)
            return gson.fromJson(jsonString, NotificationSettings::class.java)
        }
    }

    fun toJson(): String {
        return Gson().toJson(this)
    }
}