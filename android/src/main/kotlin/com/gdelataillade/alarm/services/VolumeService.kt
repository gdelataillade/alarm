package com.gdelataillade.alarm.services

import android.content.Context
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlin.math.round
import io.flutter.Log

class VolumeService(context: Context) {
    companion object {
        private const val TAG = "VolumeService"
    }

    private var previousVolume: Int? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var targetVolume: Int = 0
    private var volumeCheckRunnable: Runnable? = null
    private var activeStream: Int = AudioManager.STREAM_ALARM

    fun setVolume(volume: Double, volumeEnforced: Boolean, showSystemUI: Boolean, preferConnectedAudioDevice: Boolean) {
        activeStream = if (preferConnectedAudioDevice) AudioManager.STREAM_MUSIC else AudioManager.STREAM_ALARM
        val maxVolume = audioManager.getStreamMaxVolume(activeStream)
        previousVolume = audioManager.getStreamVolume(activeStream)
        targetVolume = (round(volume * maxVolume)).toInt()
        audioManager.setStreamVolume(
            activeStream,
            targetVolume,
            if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0
        )

        if (volumeEnforced) {
            startVolumeEnforcement(showSystemUI)
        }
    }

    private fun startVolumeEnforcement(showSystemUI: Boolean) {
        // Define the Runnable that checks and enforces the volume level
        volumeCheckRunnable = Runnable {
            val currentVolume = audioManager.getStreamVolume(activeStream)
            if (currentVolume != targetVolume) {
                audioManager.setStreamVolume(
                    activeStream,
                    targetVolume,
                    if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0
                )
            }
            // Schedule the next check after 1000ms
            handler.postDelayed(volumeCheckRunnable!!, 1000)
        }
        // Start the first run
        handler.post(volumeCheckRunnable!!)
    }

    private fun stopVolumeEnforcement() {
        // Remove callbacks to stop enforcing volume
        volumeCheckRunnable?.let { handler.removeCallbacks(it) }
        volumeCheckRunnable = null
    }

    fun restorePreviousVolume(showSystemUI: Boolean) {
        // Stop the volume enforcement if it's active
        stopVolumeEnforcement()

        // Restore the previous volume
        previousVolume?.let { prevVolume ->
            audioManager.setStreamVolume(
                activeStream,
                prevVolume,
                if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0
            )
            previousVolume = null
        }
    }

    fun requestAudioFocus(preferConnectedAudioDevice: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val usage = if (preferConnectedAudioDevice)
                AudioAttributes.USAGE_MEDIA
            else
                AudioAttributes.USAGE_ALARM
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(usage)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            focusRequest =
                AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(audioAttributes)
                    .build()

            val result = audioManager.requestAudioFocus(focusRequest!!)
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "Audio focus request failed")
            }
        } else {
            val stream = if (preferConnectedAudioDevice)
                AudioManager.STREAM_MUSIC
            else
                AudioManager.STREAM_ALARM
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                null,
                stream,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
            )
            if (result != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "Audio focus request failed")
            }
        }
    }

    fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let {
                audioManager.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }
}