package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.NotificationSettings
import com.gdelataillade.alarm.models.VolumeSettings
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Date

/**
 * Whether a delivery still describes the alarm that is stored.
 *
 * An alarm due within 5s is armed with an uncancellable `Handler.postDelayed`, so one can
 * outlive its own `Alarm.stop` or a re-set that moved it — and the delivery carries its
 * settings in the intent extras, so nothing downstream noticed. Storage is the tiebreak,
 * and `AlarmScheduler.schedule` keeps the two in step by writing both from one object.
 */
class AlarmServiceTest {
    private fun alarm(id: Int, dueAt: Long) = AlarmSettings(
        id = id,
        dateTime = Date(dueAt),
        assetAudioPath = "assets/alarm.mp3",
        volumeSettings = VolumeSettings(
            volume = null,
            fadeDuration = null,
            fadeSteps = emptyList(),
            volumeEnforced = false,
        ),
        notificationSettings = NotificationSettings(title = "Wake up", body = ""),
        loopAudio = true,
        vibrate = true,
        warningNotificationOnKill = true,
        androidFullScreenIntent = true,
    )

    @Test
    fun `a delivery matching the stored alarm rings`() {
        val due = 1_786_086_270_000
        assertTrue(AlarmService.isCurrentDelivery(alarm(42, due), alarm(42, due)))
    }

    @Test
    fun `a delivery for an alarm no longer stored is refused`() {
        // Alarm.stop unsaves, but cannot cancel the postDelayed runnable.
        assertFalse(AlarmService.isCurrentDelivery(alarm(42, 1_786_086_270_000), null))
    }

    @Test
    fun `a delivery superseded by a re-arm is refused`() {
        // The old runnable survives the re-set and would ring at the old time.
        val stored = alarm(42, 1_786_086_330_000)
        assertFalse(AlarmService.isCurrentDelivery(alarm(42, 1_786_086_270_000), stored))
    }

    @Test
    fun `a re-arm one millisecond later is still a different alarm`() {
        // Exact equality is what the storage-and-extras invariant guarantees, so nothing
        // here should soften it into a tolerance.
        val stored = alarm(42, 1_786_086_270_001)
        assertFalse(AlarmService.isCurrentDelivery(alarm(42, 1_786_086_270_000), stored))
    }
}
