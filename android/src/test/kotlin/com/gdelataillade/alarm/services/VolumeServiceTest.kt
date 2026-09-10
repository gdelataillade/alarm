package com.gdelataillade.alarm.services

import android.media.AudioManager
import com.gdelataillade.alarm.services.VolumeService.SavedVolume
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Which level enforcement pins when the alarm named no volume — and during a burst of
 * alarms, why the live stream reading is not it.
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
        // The live 7 is a predecessor's forced level, not the user's.
        val saved = SavedVolume(stream = alarm, level = 3)
        assertEquals(3, VolumeService.implicitEnforcementTarget(saved, alarm, 7))
    }

    @Test
    fun `a saved level for another stream is not usable`() {
        val saved = SavedVolume(stream = music, level = 3)
        assertEquals(7, VolumeService.implicitEnforcementTarget(saved, alarm, 7))
    }

    @Test
    fun `a muted stream is left alone`() {
        assertNull(VolumeService.implicitEnforcementTarget(null, alarm, 0))
    }

    @Test
    fun `a saved level of zero is left alone too`() {
        val saved = SavedVolume(stream = alarm, level = 0)
        assertNull(VolumeService.implicitEnforcementTarget(saved, alarm, 5))
    }
}
