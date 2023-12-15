package com.gdelataillade.alarm.services

import android.content.Context
import android.media.MediaPlayer
import java.util.concurrent.ConcurrentHashMap
import java.util.Timer
import java.util.TimerTask

class AudioService(private val context: Context) {
    private val mediaPlayers = ConcurrentHashMap<Int, MediaPlayer>()
    private val timers = ConcurrentHashMap<Int, Timer>()

    private var onAudioComplete: (() -> Unit)? = null

    fun setOnAudioCompleteListener(listener: () -> Unit) {
        onAudioComplete = listener
    }

    fun isMediaPlayerEmpty(): Boolean {
        return mediaPlayers.isEmpty()
    }

    fun getPlayingMediaPlayersIds(): List<Int> {
        return mediaPlayers.filter { (_, mediaPlayer) -> mediaPlayer.isPlaying }.keys.toList()
    }

    fun playAudio(id: Int, assetAudioPath: String, loopAudio: Boolean, fadeDuration: Double?) {
        stopAudio(id) // Stop and release any existing MediaPlayer and Timer for this ID

        try {
            val assetManager = context.assets
            val descriptor = assetManager.openFd("flutter_assets/$assetAudioPath")
            MediaPlayer().apply {
                setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                prepare()
                isLooping = loopAudio
                start()

                setOnCompletionListener {
                    if (!loopAudio) {
                        onAudioComplete?.invoke()
                    }
                }

                mediaPlayers[id] = this

                if (fadeDuration != null && fadeDuration > 0) {
                    val timer = Timer(true)
                    timers[id] = timer
                    startFadeIn(this, fadeDuration, timer)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stopAudio(id: Int) {
        timers[id]?.cancel()
        timers.remove(id)

        mediaPlayers[id]?.apply {
            if (isPlaying) {
                stop()
            }
            release()
        }
        mediaPlayers.remove(id)
    }

    private fun startFadeIn(mediaPlayer: MediaPlayer, duration: Double, timer: Timer) {
        val maxVolume = 1.0f
        val fadeDuration = (duration * 1000).toLong()
        val fadeInterval = 100L
        val numberOfSteps = fadeDuration / fadeInterval
        val deltaVolume = maxVolume / numberOfSteps
        var volume = 0.0f

        timer.schedule(object : TimerTask() {
            override fun run() {
                if (!mediaPlayer.isPlaying) {
                    cancel()
                    return
                }

                mediaPlayer.setVolume(volume, volume)
                volume += deltaVolume

                if (volume >= maxVolume) {
                    mediaPlayer.setVolume(maxVolume, maxVolume)
                    cancel()
                }
            }
        }, 0, fadeInterval)
    }

    fun cleanUp() {
        timers.values.forEach(Timer::cancel)
        timers.clear()

        mediaPlayers.values.forEach { mediaPlayer ->
            if (mediaPlayer.isPlaying) {
                mediaPlayer.stop()
            }
            mediaPlayer.release()
        }
        mediaPlayers.clear()
    }
}
