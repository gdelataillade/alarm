package com.gdelataillade.alarm.services

import android.content.Context
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.os.Build
import kotlin.math.round

class VolumeService(private val context: Context) {
    private var previousVolume: Int? = null
    private var showSystemUI: Boolean = true
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun setVolume(volume: Double, showVolumeSystemUI: Boolean) {
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        showSystemUI = showVolumeSystemUI
        val _volume = (round(volume * maxVolume)).toInt()
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, _volume, if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0)
    }

    fun restorePreviousVolume() {
        previousVolume?.let { prevVolume ->
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, prevVolume, if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0)
            previousVolume = null
        }
    }

    fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(audioAttributes)
                .build()

            audioManager.requestAudioFocus(focusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
        }
    }

    fun abandonAudioFocus() {
        audioManager.abandonAudioFocus(null)
    }
}
