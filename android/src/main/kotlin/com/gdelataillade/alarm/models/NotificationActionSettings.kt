package com.gdelataillade.alarm.models

import org.json.JSONObject

data class NotificationActionSettings(
    val hasStopButton: Boolean = false,
    val hasSnoozeButton: Boolean = false,
    val stopButtonText: String = "Stop",
    val snoozeButtonText: String = "Snooze",
    val snoozeDurationInSeconds: Int = 9 * 60
) {
    companion object {
        fun fromJson(json: JSONObject): NotificationActionSettings {
            return NotificationActionSettings(
                hasStopButton = json.optBoolean("hasStopButton", false),
                hasSnoozeButton = json.optBoolean("hasSnoozeButton", false),
                stopButtonText = json.optString("stopButtonText", "Stop"),
                snoozeButtonText = json.optString("snoozeButtonText", "Snooze"),
                snoozeDurationInSeconds = json.optInt("snoozeDurationInSeconds", 9 * 60)
            )
        }
    }
}