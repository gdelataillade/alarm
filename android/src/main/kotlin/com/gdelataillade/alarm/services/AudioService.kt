package com.gdelataillade.alarm.services

import android.content.Context
import android.media.MediaPlayer
import java.util.concurrent.ConcurrentHashMap
import java.util.Timer
import java.util.TimerTask
import io.flutter.Log

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

    fun playAudio(id: Int, filePath: String, loopAudio: Boolean, fadeDuration: Double?, fadeStopTimes: List<Double>, fadeStopVolumes: List<Double>) {
        stopAudio(id) // Stop and release any existing MediaPlayer and Timer for this ID

        val baseAppFlutterPath = context.filesDir.parent?.plus("/app_flutter/")
        val adjustedFilePath = when {
            filePath.startsWith("assets/") -> "flutter_assets/$filePath"
            !filePath.startsWith("/") -> baseAppFlutterPath + filePath
            else -> filePath
        }

        try {
            MediaPlayer().apply {
                when {
                    adjustedFilePath.startsWith("flutter_assets/") -> {
                        // It's an asset file
                        val assetManager = context.assets
                        val descriptor = assetManager.openFd(adjustedFilePath)
                        setDataSource(
                            descriptor.fileDescriptor,
                            descriptor.startOffset,
                            descriptor.length
                        )
                    }

                    else -> {
                        // Handle local files and adjusted paths
                        setDataSource(adjustedFilePath)
                    }
                }

                prepare()
                isLooping = loopAudio
                start()

                setOnCompletionListener {
                    if (!loopAudio) {
                        onAudioComplete?.invoke()
                    }
                }

                mediaPlayers[id] = this

                if (fadeStopTimes.isNotEmpty()) {
                    val timer = Timer(true)
                    timers[id] = timer
                    startStaircaseFadeIn(this, fadeStopTimes, fadeStopVolumes, timer)
                } else if (fadeDuration != null && fadeDuration > 0) {
                    val timer = Timer(true)
                    timers[id] = timer
                    startFadeIn(this, fadeDuration, timer)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Log.e("AudioService", "Error playing audio: $e")
        }
    }

    fun stopAudio(id: Int) {
        timers[id]?.cancel()
        timers.remove(id)

        mediaPlayers[id]?.apply {
            if (isPlaying) {
                stop()
            }
            reset()
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

    private fun startStaircaseFadeIn(mediaPlayer: MediaPlayer, stopTimes: List<Double>, stopVolumes: List<Double>, timer: Timer) {
        if (stopTimes.size != stopVolumes.size) {
            Log.e("AudioService", "Stop times and volumes don't have the same length.")
            return
        }

        val fadeInterval = 100L
        var currentStep = 0

        timer.schedule(object : TimerTask() {
            override fun run() {
                if (!mediaPlayer.isPlaying) {
                    cancel()
                    return
                }

                val currentTime = (currentStep * fadeInterval) / 1000
                val nextIndex = stopTimes.indexOfFirst { it >= currentTime }

                if (nextIndex < 0) {
                    cancel()
                    return
                }

                val nextVolume = stopVolumes[nextIndex]
                var currentVolume = nextVolume

                if (nextIndex > 0) {
                    val prevTime = stopTimes[nextIndex - 1]
                    val nextTime = stopTimes[nextIndex]
                    val nextRatio = (currentTime - prevTime) / (nextTime - prevTime)

                    val prevVolume = stopVolumes[nextIndex - 1]
                    currentVolume = nextVolume * nextRatio + prevVolume * (1 - nextRatio)
                }

                mediaPlayer.setVolume(currentVolume.toFloat(), currentVolume.toFloat())
                currentStep++
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
            mediaPlayer.reset()
            mediaPlayer.release()
        }
        mediaPlayers.clear()
    }
}
