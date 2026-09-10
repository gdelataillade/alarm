package com.gdelataillade.alarm.services

import android.media.AudioManager
import com.gdelataillade.alarm.services.VolumeService.SavedVolume
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Which level an alarm that named no volume rings at — and why the live stream reading is
 * sometimes the user's own level and sometimes another alarm's.
 */
class VolumeServiceTest {
    private val alarm = AudioManager.STREAM_ALARM
    private val music = AudioManager.STREAM_MUSIC

    private fun target(
        saved: SavedVolume?,
        currentLevel: Int,
        otherAlarmPlaying: Boolean = false,
    ) = VolumeService.implicitEnforcementTarget(saved, alarm, currentLevel, otherAlarmPlaying)

    @Test
    fun `with nothing saved the live level is the user's own`() {
        assertEquals(4, target(null, 4))
    }

    @Test
    fun `a saved level for this stream beats the live one`() {
        // The live 7 is a stopped predecessor's forced level, not the user's.
        assertEquals(3, target(SavedVolume(alarm, 3), 7))
    }

    @Test
    fun `a saved level for another stream is not usable`() {
        assertEquals(7, target(SavedVolume(music, 3), 7))
    }

    @Test
    fun `while another alarm sounds its level wins over the saved one`() {
        // Overlap: the live 7 is that alarm's explicit choice, and an alarm with no
        // opinion must not quieten it.
        assertEquals(7, target(SavedVolume(alarm, 3), 7, otherAlarmPlaying = true))
    }

    @Test
    fun `a saved mute is honoured over a raised stream`() {
        // The caller restores this before skipping enforcement, so the alarm rings at the
        // user's silence rather than at the predecessor's volume.
        assertEquals(0, target(SavedVolume(alarm, 0), 7))
    }

    @Test
    fun `an already muted stream stays muted`() {
        assertEquals(0, target(null, 0))
    }
}
