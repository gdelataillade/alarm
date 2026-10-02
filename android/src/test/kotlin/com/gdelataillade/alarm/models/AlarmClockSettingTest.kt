package com.gdelataillade.alarm.models

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/** `androidAlarmClock` defaults to true, including for alarms stored before it existed (#439). */
class AlarmClockSettingTest {
    private fun settings(alarmClock: Boolean = true) = AlarmSettings(
        id = 42,
        dateTime = Date(1_786_086_270_000),
        assetAudioPath = null,
        volumeSettings = VolumeSettings(
            volume = null,
            fadeDuration = null,
            fadeSteps = emptyList(),
            volumeEnforced = false,
        ),
        notificationSettings = NotificationSettings(title = "Title", body = "Body"),
        loopAudio = true,
        vibrate = true,
        warningNotificationOnKill = true,
        androidFullScreenIntent = true,
        androidAlarmClock = alarmClock,
    )

    @Test
    fun `an alarm stored before the setting existed is an alarm clock`() {
        val json = Json.encodeToString(settings())
        assertFalse(json.contains("androidAlarmClock"))

        assertTrue(Json.decodeFromString<AlarmSettings>(json).androidAlarmClock)
        assertTrue(AlarmSettings.fromJson(json).androidAlarmClock)
    }

    @Test
    fun `an opt-out survives storage`() {
        val json = Json.encodeToString(settings(alarmClock = false))

        assertFalse(Json.decodeFromString<AlarmSettings>(json).androidAlarmClock)
        assertFalse(AlarmSettings.fromJson(json).androidAlarmClock)
    }
}
