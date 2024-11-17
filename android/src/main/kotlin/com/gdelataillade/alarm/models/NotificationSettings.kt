package com.gdelataillade.alarm.models

import NotificationSettingsWire
import com.google.gson.Gson

data class NotificationSettings(
    val title: String,
    val body: String,
    val stopButton: String? = null,
    val icon: String? = null
) {
    companion object {
        fun fromWire(e: NotificationSettingsWire): NotificationSettings {
            return NotificationSettings(
                e.title,
                e.body,
                e.stopButton,
                e.icon,
            )
        }
    }

    fun toWire(): NotificationSettingsWire {
        return NotificationSettingsWire(
            title,
            body,
            stopButton,
            icon,
        )
    }

    fun toJson(): String {
        return Gson().toJson(this)
    }
}