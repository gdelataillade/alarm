package com.gdelataillade.alarm.services

import android.content.Context
import android.media.MediaPlayer
import java.util.Timer
import java.util.TimerTask
import kotlin.math.round

class AudioService(private val context: Context) {
    private val mediaPlayers = mutableMapOf<Int, MediaPlayer>()

    fun isMediaPlayerEmpty(): Boolean {
        return mediaPlayers.isEmpty()
    }

    fun getPlayingMediaPlayersIds(): List<Int> {
        return mediaPlayers.filter { (_, mediaPlayer) -> mediaPlayer.isPlaying }.keys.toList()
    }

    fun playAudio(id: Int, assetAudioPath: String, loopAudio: Boolean, fadeDuration: Double?) {
        try {
            mediaPlayers.forEach { (_, mediaPlayer) ->
                if (mediaPlayer.isPlaying) {
                    mediaPlayer.stop()
                    mediaPlayer.release()
                }
            }

            val assetManager = context.assets
            val descriptor = assetManager.openFd("flutter_assets/$assetAudioPath")
            val mediaPlayer = MediaPlayer().apply {
                setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                prepare()
                isLooping = loopAudio
            }
            mediaPlayer.start()

            mediaPlayers[id] = mediaPlayer

            if (fadeDuration != null && fadeDuration > 0) {
                startFadeIn(mediaPlayer, fadeDuration)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stopAudio(id: Int) {
        mediaPlayers[id]?.stop()
        mediaPlayers[id]?.release()
        mediaPlayers.remove(id)
    }

    private fun startFadeIn(mediaPlayer: MediaPlayer, duration: Double) {
        val maxVolume = 1.0f // Use 1.0f for MediaPlayer's max volume
        val fadeDuration = (duration * 1000).toLong() // Convert seconds to milliseconds
        val fadeInterval = 100L // Interval for volume increment
        val numberOfSteps = fadeDuration / fadeInterval // Number of volume increments
        val deltaVolume = maxVolume / numberOfSteps // Volume increment per step

        val timer = Timer(true) // Use a daemon thread
        var volume = 0.0f

        val timerTask = object : TimerTask() {
            override fun run() {
                mediaPlayer.setVolume(volume, volume) // Set volume for both channels
                volume += deltaVolume

                if (volume >= maxVolume) {
                    mediaPlayer.setVolume(maxVolume, maxVolume) // Ensure max volume is set
                    this.cancel() // Cancel the timer
                }
            }
        }

        timer.schedule(timerTask, 0, fadeInterval)
    }

    fun cleanUp() {
        mediaPlayers.forEach { (_, mediaPlayer) ->
            mediaPlayer.stop()
            mediaPlayer.release()
        }
        mediaPlayers.clear()
    }
}
