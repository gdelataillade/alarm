package com.gdelataillade.alarm.models

import NotificationSettingsWire
import kotlinx.serialization.Serializable

@Serializable
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
}