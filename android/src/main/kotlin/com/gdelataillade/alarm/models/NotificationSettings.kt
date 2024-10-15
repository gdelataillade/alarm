package com.gdelataillade.alarm.models

import com.google.gson.Gson

data class NotificationSettings(
    val title: String,
    val body: String,
    val stopButton: String? = null,
    val icon: String? = null
) {
    fun toJson(): String {
        return Gson().toJson(this)
    }
}