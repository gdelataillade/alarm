package com.gdelataillade.alarm.services

import android.media.AudioManager
import com.gdelataillade.alarm.services.VolumeService.SavedVolume
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Which level enforcement pins when the alarm named no volume.
 *
 * `volumeEnforced` with no `volume` protects the user's own level instead of replacing it,
 * so the question is which reading counts as "the user's own" — and during a burst of
 * alarms the live stream is not it.
 */
class VolumeServiceTest {
    private val alarm = AudioManager.STREAM_ALARM
    private val music = AudioManager.STREAM_MUSIC

    @Test
    fun `with nothing saved the live level is the user's own`() {
        assertEquals(4, VolumeService.implicitEnforcementTarget(null, alarm, 4))
    }

    @Test
    fun `a saved level for this stream beats the live one`() {
        // At a queue promotion the stream is still raised by the alarm that just stopped,
        // so the live reading is a predecessor's forced level, not the user's.
        val saved = SavedVolume(stream = alarm, level = 3)
        assertEquals(3, VolumeService.implicitEnforcementTarget(saved, alarm, 7))
    }

    @Test
    fun `a saved level for another stream is not usable`() {
        // A previous alarm routed to Bluetooth saved a STREAM_MUSIC level, which says
        // nothing about the alarm stream this one is about to enforce.
        val saved = SavedVolume(stream = music, level = 3)
        assertEquals(7, VolumeService.implicitEnforcementTarget(saved, alarm, 7))
    }

    @Test
    fun `a muted stream is left alone`() {
        // Pinning zero would make the alarm silent and unraisable, which is the opposite
        // of what enforcement is for.
        assertNull(VolumeService.implicitEnforcementTarget(null, alarm, 0))
    }

    @Test
    fun `a saved level of zero is left alone too`() {
        val saved = SavedVolume(stream = alarm, level = 0)
        assertNull(VolumeService.implicitEnforcementTarget(saved, alarm, 5))
    }
}
