package com.gdelataillade.alarm.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.media.AudioManager
import android.media.AudioManager.FLAG_SHOW_UI
import android.os.*
import androidx.core.app.NotificationCompat
import io.flutter.Log
import kotlin.math.round

class AlarmService : Service() {
    private val mediaPlayers = mutableMapOf<Int, MediaPlayer>()
    private var vibrator: Vibrator? = null
    private val CHANNEL_ID = "AlarmServiceChannel"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AlarmService", "onStartCommand")

        val action = intent?.action
        val id = intent?.getIntExtra("id", 0) ?: 0

        if (action == "STOP_ALARM" && id != -1) {
            stopAlarm(id)
            return START_NOT_STICKY
        }

        val assetAudioPath = intent?.getStringExtra("assetAudioPath")
        val loopAudio = intent?.getBooleanExtra("loopAudio", true)
        val vibrate = intent?.getBooleanExtra("vibrate", true)
        val volume = intent?.getDoubleExtra("volume", -1.0) ?: -1.0
        val fadeDuration = intent?.getDoubleExtra("fadeDuration", 0.0)
        val notificationTitle = intent?.getStringExtra("notificationTitle")
        val notificationBody = intent?.getStringExtra("notificationBody")
        val showSystemUI = true

        Log.d("AlarmService", "id: $id")
        Log.d("AlarmService", "assetAudioPath: $assetAudioPath")
        Log.d("AlarmService", "loopAudio: $loopAudio")
        Log.d("AlarmService", "vibrate: $vibrate")
        Log.d("AlarmService", "volume: $volume")
        Log.d("AlarmService", "fadeDuration: $fadeDuration")
        Log.d("AlarmService", "notificationTitle: $notificationTitle")
        Log.d("AlarmService", "notificationBody: $notificationBody")

        if (notificationTitle != null && notificationBody != null) {
            val iconResId = applicationContext.resources.getIdentifier("ic_launcher", "mipmap", applicationContext.packageName)
            val intent = applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
            val pendingIntent = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(notificationTitle)
                .setContentText(notificationBody)
                .setSmallIcon(iconResId)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)  // Automatically remove the notification when tapped
                .build()

            startForeground(id!!, notification)
        }

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (volume != -1.0) {
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val _volume = (round(volume * maxVolume)).toInt()

            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, _volume, if (showSystemUI) FLAG_SHOW_UI else 0)
        }

        // Request audio focus
        val focusRequestResult = audioManager.requestAudioFocus(
            null,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
        )

        try {
            val assetManager = applicationContext.assets
            val descriptor = assetManager.openFd("flutter_assets/" + assetAudioPath!!)

            val mediaPlayer = MediaPlayer().apply {
                setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                prepare()
                isLooping = loopAudio!!
            }
            mediaPlayer.start()

            // Store MediaPlayer instance in map
            mediaPlayers[id] = mediaPlayer

        } catch (e: Exception) {
            // Handle exceptions related to asset loading or MediaPlayer
            e.printStackTrace()
        }

        if (vibrate!!) {
            // Obtain Vibrator instance if not already obtained
            if (vibrator == null) {
                vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            // Vibrate the device in a loop: vibrate for 500ms, pause for 500ms
            val pattern = longArrayOf(0, 500, 500)  // Start immediately, vibrate 500ms, pause 500ms
            val repeat = 1  // Repeat from the second element (0-based) of the pattern, which is the pause
            val vibrationEffect = VibrationEffect.createWaveform(pattern, repeat)
            vibrator?.vibrate(vibrationEffect)
        }

        // Wake up the device
        val wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP, "app:AlarmWakelockTag")
        wakeLock.acquire(5 * 60 * 1000L /*5 minutes*/)

        return START_STICKY
    }

    fun stopAlarm(id: Int) {
        mediaPlayers[id]?.stop()
        mediaPlayers[id]?.release()
        mediaPlayers.remove(id)

        // Abandon audio focus
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.abandonAudioFocus(null)

        // Check if there are no more active alarms
        if (mediaPlayers.isEmpty()) {
            vibrator?.cancel()
            stopForeground(true)
            stopSelf()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    override fun onDestroy() {
        mediaPlayers.values.forEach {
            it.stop()
            it.release()
        }
        mediaPlayers.clear()
        vibrator?.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
