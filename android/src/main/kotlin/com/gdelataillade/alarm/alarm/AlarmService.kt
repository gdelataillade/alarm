package com.gdelataillade.alarm.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.media.AudioManager
import android.media.AudioManager.FLAG_SHOW_UI
import android.provider.Settings
import android.os.*
import androidx.core.app.NotificationCompat
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import kotlin.math.round
import java.util.Timer
import java.util.TimerTask

class AlarmService : Service() {
    private val mediaPlayers = mutableMapOf<Int, MediaPlayer>()
    private var vibrator: Vibrator? = null
    private var previousVolume: Int? = null
    private var showSystemUI: Boolean = true
    private val CHANNEL_ID = "AlarmServiceChannel"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    companion object {
        @JvmStatic
        var isRinging: Boolean = false
            private set
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
        showSystemUI = intent?.getBooleanExtra("showSystemUI", true) ?: true

        Log.d("AlarmService", "id: $id")
        Log.d("AlarmService", "assetAudioPath: $assetAudioPath")
        Log.d("AlarmService", "loopAudio: $loopAudio")
        Log.d("AlarmService", "vibrate: $vibrate")
        Log.d("AlarmService", "volume: $volume")
        Log.d("AlarmService", "fadeDuration: $fadeDuration")
        Log.d("AlarmService", "notificationTitle: $notificationTitle")
        Log.d("AlarmService", "notificationBody: $notificationBody")

        isRinging = true

        // Create a new FlutterEngine instance.
        val flutterEngine = FlutterEngine(this)

        // Start executing Dart code to prepare for method channel communication.
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        val flutterChannel = MethodChannel(flutterEngine?.dartExecutor, "com.gdelataillade.alarm/alarm")
        flutterChannel.invokeMethod("alarmRinging", mapOf("id" to id))

        if (notificationTitle != null && notificationBody != null) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val areNotificationsEnabled = manager.areNotificationsEnabled()

            if (!areNotificationsEnabled) {
                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                startActivity(intent)
            }

            val iconResId = applicationContext.resources.getIdentifier("ic_launcher", "mipmap", applicationContext.packageName)
            val intent = applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
            val pendingIntent = PendingIntent.getActivity(this, id!!, intent, PendingIntent.FLAG_UPDATE_CURRENT)

            val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(iconResId)
                .setContentTitle(notificationTitle)
                .setContentText(notificationBody)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

            startForeground(id!!, notificationBuilder.build())
        }

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        if (volume != -1.0) {
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC) // Save the previous volume
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

            if (fadeDuration != null && fadeDuration > 0) {
                startFadeIn(mediaPlayer, fadeDuration)
            }
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

        Log.d("AlarmService => SET ALARM", "Current mediaPlayers keys: ${mediaPlayers.keys}")

        return START_STICKY
    }

    fun stopAlarm(id: Int) {
        Log.d("AlarmService => STOP ALARM", "id: $id")
        Log.d("AlarmService => STOP ALARM", "Current mediaPlayers keys: ${mediaPlayers.keys}")
        Log.d("AlarmService => STOP ALARM", "previousVolume: $previousVolume")

        isRinging = false

        previousVolume?.let { prevVolume ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, prevVolume, if (showSystemUI) FLAG_SHOW_UI else 0)
            previousVolume = null // Reset the previous volume
        }

        if (mediaPlayers.containsKey(id)) {
            Log.d("AlarmService => STOP ALARM", "Stopping MediaPlayer with id: $id")
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
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Service Channel",
                NotificationManager.IMPORTANCE_MAX
            )

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
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

    override fun onDestroy() {
        isRinging = false

        // Clean up MediaPlayer resources
        mediaPlayers.values.forEach {
            it.stop()
            it.release()
        }
        mediaPlayers.clear()

        // Cancel any ongoing vibration
        vibrator?.cancel()

        // Restore system volume if it was changed
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        previousVolume?.let { prevVolume ->
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, prevVolume, if (showSystemUI) FLAG_SHOW_UI else 0)
        }

        // Stop the foreground service and remove the notification
        stopForeground(true)

        // Call the superclass method
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
