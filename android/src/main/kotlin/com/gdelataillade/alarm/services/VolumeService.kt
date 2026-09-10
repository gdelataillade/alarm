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
         * The level to pin when the alarm named no volume, or null to skip enforcement.
         *
         * Prefers [saved], which is the user's own level for this burst: at a queue
         * promotion the stream is still raised by the alarm that just stopped, so reading
         * it live would pin a predecessor's forced level (#444). Only usable when it
         * belongs to the stream being enforced.
         *
         * Returns null for a muted stream. "No volume" means no opinion, and pinning zero
         * would make the alarm silent *and* unraisable, which inverts what enforcement is
         * for. An explicit `volume: 0.0` does not come through here and still pins.
         */
        internal fun implicitEnforcementTarget(
            saved: SavedVolume?,
            activeStream: Int,
            currentLevel: Int,
        ): Int? {
            val level =
                if (saved != null && saved.stream == activeStream) saved.level else currentLevel
            return level.takeIf { it > 0 }
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

    /**
     * Enforces the level the stream already reads, without changing it.
     *
     * `volumeEnforced` with no `volume` asks for the user's own level to be protected
     * rather than replaced — the two settings answer different questions (#438). iOS has
     * done this since its rewrite; this brings Android in line.
     */
    fun enforceCurrentVolume(showSystemUI: Boolean, preferConnectedAudioDevice: Boolean) {
        stopVolumeEnforcement()

        activeStream =
            if (preferConnectedAudioDevice) AudioManager.STREAM_MUSIC else AudioManager.STREAM_ALARM
        val target = implicitEnforcementTarget(
            savedVolume,
            activeStream,
            audioManager.getStreamVolume(activeStream),
        )
        if (target == null) {
            Log.d(TAG, "Alarm stream is muted; not pinning a level the user could not raise.")
            return
        }

        // No setStreamVolume and no savedVolume: nothing is changed, so nothing to restore.
        targetVolume = target
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