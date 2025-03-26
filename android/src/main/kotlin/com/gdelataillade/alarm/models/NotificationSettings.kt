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
    val iconColor: Int? = null
) {
    companion object {
        fun fromWire(e: NotificationSettingsWire): NotificationSettings {
            val a = (e.iconColorAlpha as? String)?.toFloatOrNull()
            val r = (e.iconColorRed as? String)?.toFloatOrNull()
            val g = (e.iconColorGreen as? String)?.toFloatOrNull()
            val b = (e.iconColorBlue as? String)?.toFloatOrNull()

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
            )
        }
    }
}