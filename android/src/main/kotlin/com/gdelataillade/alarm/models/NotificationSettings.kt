package com.gdelataillade.alarm.models

import android.graphics.Color
import com.gdelataillade.alarm.generated.NotificationSettingsWire
import kotlinx.serialization.Serializable

@Serializable
data class NotificationSettings(
    val title: String,
    val body: String,
    val stopButton: String? = null,
    val icon: String? = null,
    val iconColor: Int? = null,
    val keepNotificationAfterAlarmEnds: Boolean = false,
) {
    companion object {
        fun fromWire(e: NotificationSettingsWire): NotificationSettings {
            val a = e.iconColorAlpha?.toFloat()
            val r = e.iconColorRed?.toFloat()
            val g = e.iconColorGreen?.toFloat()
            val b = e.iconColorBlue?.toFloat()

            var iconColor: Int? = null
            if (a != null && r != null && g != null && b != null) {
                iconColor = Color.argb(a, r, g, b)
            }

            return NotificationSettings(
                e.title,
                e.body,
                e.stopButton,
                e.icon,
                iconColor,
                e.keepNotificationAfterAlarmEnds,
            )
        }
    }
}