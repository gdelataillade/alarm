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

        /**
         * The level an alarm that named no volume should ring at.
         *
         * With another alarm still sounding, the live level is its explicit choice and a
         * no-opinion alarm must not override it. Otherwise a stopped predecessor may have
         * left the stream raised, and [saved] is the user's own level.
         */
        internal fun implicitEnforcementTarget(
            saved: SavedVolume?,
            activeStream: Int,
            currentLevel: Int,
            otherAlarmPlaying: Boolean,
        ): Int {
            if (otherAlarmPlaying) return currentLevel
            return if (saved != null && saved.stream == activeStream) saved.level else currentLevel
        }
    }

    /** What to put back, and on which stream. Captured once per burst of alarms. */
    internal data class SavedVolume(val stream: Int, val level: Int)

    private var savedVolume: SavedVolume? = null
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var targetVolume: Int = 0
    private var volumeCheckRunnable: Runnable? = null
    private var activeStream: Int = AudioManager.STREAM_ALARM

    fun setVolume(volume: Double, volumeEnforced: Boolean, showSystemUI: Boolean, preferConnectedAudioDevice: Boolean) {
        // This ring supersedes the previous one's enforcement whether or not it wants
        // its own, otherwise the old target keeps being forced (#444).
        stopVolumeEnforcement()

        activeStream = if (preferConnectedAudioDevice) AudioManager.STREAM_MUSIC else AudioManager.STREAM_ALARM
        // Only the first alarm of a burst sees the user's own level; a later one would
        // record what its predecessor had already forced.
        if (savedVolume == null) {
            savedVolume = SavedVolume(activeStream, audioManager.getStreamVolume(activeStream))
        }
        val maxVolume = audioManager.getStreamMaxVolume(activeStream)
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

    /** Rings at the user's own level and holds it there, choosing no level of its own (#438). */
    fun enforceCurrentVolume(
        showSystemUI: Boolean,
        preferConnectedAudioDevice: Boolean,
        otherAlarmPlaying: Boolean,
    ) {
        stopVolumeEnforcement()

        activeStream =
            if (preferConnectedAudioDevice) AudioManager.STREAM_MUSIC else AudioManager.STREAM_ALARM
        val live = audioManager.getStreamVolume(activeStream)
        val level =
            implicitEnforcementTarget(savedVolume, activeStream, live, otherAlarmPlaying)

        // A stopped predecessor may have left the stream raised, so put it back even when
        // enforcement is then skipped. savedVolume is left as it is: this chose no level.
        if (level != live) {
            audioManager.setStreamVolume(
                activeStream,
                level,
                if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0
            )
        }

        if (level == 0) {
            Log.d(TAG, "Alarm stream is muted; not pinning a level the user could not raise.")
            return
        }

        targetVolume = level
        startVolumeEnforcement(showSystemUI)
    }

    /**
     * Holds the stream at [targetVolume] until enforcement stops.
     *
     * [setVolume] cancels any previous runnable before calling this, so none is ever
     * orphaned; re-posting `this` rather than the field, and the identity check, are what
     * keep an orphan from being fatal if one ever is (#437).
     */
    private fun startVolumeEnforcement(showSystemUI: Boolean) {
        val runnable = object : Runnable {
            override fun run() {
                if (volumeCheckRunnable !== this) return

                val currentVolume = audioManager.getStreamVolume(activeStream)
                if (currentVolume != targetVolume) {
                    audioManager.setStreamVolume(
                        activeStream,
                        targetVolume,
                        if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0
                    )
                }
                // Schedule the next check after 1000ms
                handler.postDelayed(this, 1000)
            }
        }

        volumeCheckRunnable = runnable
        handler.post(runnable)
    }

    /** Public because a ring that sets no volume never reaches [setVolume]. */
    fun stopVolumeEnforcement() {
        volumeCheckRunnable?.let { handler.removeCallbacks(it) }
        volumeCheckRunnable = null
    }

    fun restorePreviousVolume(showSystemUI: Boolean) {
        stopVolumeEnforcement()

        // The saved stream, not activeStream: a later alarm may have moved that.
        savedVolume?.let { saved ->
            audioManager.setStreamVolume(
                saved.stream,
                saved.level,
                if (showSystemUI) AudioManager.FLAG_SHOW_UI else 0
            )
            savedVolume = null
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