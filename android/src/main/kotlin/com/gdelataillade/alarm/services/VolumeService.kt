package com.gdelataillade.alarm.services

import android.content.Context
import android.media.AudioManager
import kotlin.math.round

class VolumeService(private val context: Context) {
    private var previousVolume: Int? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun setVolume(volume: Double, showSystemUI: Boolean) {
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        val _volume = (round(volume * maxVolume)).toInt()
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, _volume, if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0)
    }

    fun restorePreviousVolume(showSystemUI: Boolean) {
        previousVolume?.let { prevVolume ->
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, prevVolume, if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0)
            previousVolume = null
        }
    }

    fun requestAudioFocus() {
        audioManager.requestAudioFocus(
            null,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
        )
    }

    fun abandonAudioFocus() {
        audioManager.abandonAudioFocus(null)
    }
}
