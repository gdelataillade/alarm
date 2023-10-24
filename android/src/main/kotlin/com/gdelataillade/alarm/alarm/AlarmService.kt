package com.gdelataillade.alarm.alarm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.media.AudioManager
import android.media.AudioManager.FLAG_SHOW_UI
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import io.flutter.Log
import kotlin.math.round

class AlarmService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "AlarmServiceChannel"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AlarmService", "onStartCommand")

        val id = intent?.getIntExtra("id", 0)
        val assetAudioPath = intent?.getStringExtra("assetAudioPath")
        val loopAudio = intent?.getBooleanExtra("loopAudio", true)
        val vibrate = intent?.getBooleanExtra("vibrate", true)
        val volume = intent?.getDoubleExtra("volume", -1.0)
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

        if (volume != -1.0) {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
///
            var maxVolume:Int = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            var _volume:Int = (round(volume!! * maxVolume)).toInt()

            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, _volume, if (showSystemUI) FLAG_SHOW_UI else 0)
        }

        try {
            val assetManager = applicationContext.assets
            val descriptor = assetManager.openFd("flutter_assets/" + assetAudioPath!!)

            val mediaPlayer = MediaPlayer().apply {
                setDataSource(descriptor.fileDescriptor, descriptor.startOffset, descriptor.length)
                prepare()
                isLooping = loopAudio!!
            }
            mediaPlayer.start()

        } catch (e: Exception) {
            // Handle exceptions related to asset loading or MediaPlayer
            e.printStackTrace()
        }

        if (vibrate!!) {
            // Vibrate the device in a loop: vibrate for 500ms, pause for 500ms
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            val pattern = longArrayOf(0, 500, 500)  // Start immediately, vibrate 500ms, pause 500ms
            val repeat = 1  // Repeat from the second element (0-based) of the pattern, which is the pause
            val vibrationEffect = VibrationEffect.createWaveform(pattern, repeat)
            vibrator.vibrate(vibrationEffect)
        }

        // Wake up the device
        val wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP, "app:AlarmWakelockTag")
        wakeLock.acquire(5 * 60 * 1000L /*5 minutes*/)
        
        return START_STICKY
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
        mediaPlayer?.stop()
        mediaPlayer?.release()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
