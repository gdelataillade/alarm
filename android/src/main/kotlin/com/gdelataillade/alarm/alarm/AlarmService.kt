package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.AudioService
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.services.VibrationService
import com.gdelataillade.alarm.services.VolumeService
import com.gdelataillade.alarm.models.NotificationSettings
import com.google.gson.Gson

import android.app.Service
import android.app.PendingIntent
import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.content.Intent
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.PowerManager
import android.os.Build
import com.gdelataillade.alarm.services.AlarmRingingLiveData
import com.gdelataillade.alarm.services.NotificationHandler
import io.flutter.Log

class AlarmService : Service() {
    private var audioService: AudioService? = null
    private var vibrationService: VibrationService? = null
    private var volumeService: VolumeService? = null
    private var showSystemUI: Boolean = true

    companion object {
        @JvmStatic
        var ringingAlarmIds: List<Int> = listOf()
    }

    override fun onCreate() {
        super.onCreate()

        audioService = AudioService(this)
        vibrationService = VibrationService(this)
        volumeService = VolumeService(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent.getIntExtra("id", 0)
        val action = intent.getStringExtra(AlarmReceiver.EXTRA_ALARM_ACTION)

        if (action == "STOP_ALARM" && id != 0) {
            unsaveAlarm(id)
            return START_NOT_STICKY
        }

        // Build the notification
        val notificationHandler = NotificationHandler(this)
        val appIntent =
            applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            appIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notificationSettingsJson = intent.getStringExtra("notificationSettings")
        val notificationSettings = if (notificationSettingsJson != null) {
            val gson = Gson()
            gson.fromJson(notificationSettingsJson, NotificationSettings::class.java)
        } else {
            val notificationTitle = intent.getStringExtra("notificationTitle") ?: "Title"
            val notificationBody = intent.getStringExtra("notificationBody") ?: "Body"
            NotificationSettings(notificationTitle, notificationBody)
        }

        val fullScreenIntent = intent.getBooleanExtra("fullScreenIntent", true)
        val notification = notificationHandler.buildNotification(
            notificationSettings,
            fullScreenIntent,
            pendingIntent,
            id
        )

        // Start the service in the foreground
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    startAlarmService(id, notification)
                } catch (e: ForegroundServiceStartNotAllowedException) {
                    Log.e("AlarmService", "Foreground service start not allowed", e)
                    return START_NOT_STICKY
                }
            } else {
                startAlarmService(id, notification)
            }
        } catch (e: SecurityException) {
            Log.e("AlarmService", "Security exception in starting foreground service", e)
            return START_NOT_STICKY
        }

        // Check if an alarm is already ringing
        if (ringingAlarmIds.isNotEmpty() && action != "STOP_ALARM") {
            Log.d("AlarmService", "An alarm is already ringing. Ignoring new alarm with id: $id")
            unsaveAlarm(id)
            return START_NOT_STICKY
        }

        if (fullScreenIntent) {
            AlarmRingingLiveData.instance.update(true)
        }

        // Proceed with handling the new alarm
        val assetAudioPath = intent.getStringExtra("assetAudioPath") ?: return START_NOT_STICKY
        val loopAudio = intent.getBooleanExtra("loopAudio", true)
        val vibrate = intent.getBooleanExtra("vibrate", true)
        val volume = intent.getDoubleExtra("volume", -1.0)
        val volumeEnforced = intent.getBooleanExtra("volumeEnforced", false)
        val fadeDuration = intent.getDoubleExtra("fadeDuration", 0.0)

        // Notify the plugin about the alarm ringing
        AlarmPlugin.alarmTriggerApi?.alarmRang(id.toLong()) {
            Log.d("AlarmService", "Flutter was notified that alarm $id is ringing.")
        }

        // Set the volume if specified
        if (volume in 0.0..1.0) {
            volumeService?.setVolume(volume, volumeEnforced, showSystemUI)
        }

        // Request audio focus
        volumeService?.requestAudioFocus()

        // Set up audio completion listener
        audioService?.setOnAudioCompleteListener {
            if (!loopAudio) {
                vibrationService?.stopVibrating()
                volumeService?.restorePreviousVolume(showSystemUI)
                volumeService?.abandonAudioFocus()
            }
        }

        // Play the alarm audio
        audioService?.playAudio(id, assetAudioPath, loopAudio, fadeDuration)

        // Update the list of ringing alarms
        ringingAlarmIds = audioService?.getPlayingMediaPlayersIds() ?: listOf()

        // Start vibration if enabled
        if (vibrate) {
            vibrationService?.startVibrating(longArrayOf(0, 500, 500), 1)
        }

        // Acquire a wake lock to wake up the device
        val wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "app:AlarmWakelockTag")
        wakeLock.acquire(5 * 60 * 1000L) // Acquire for 5 minutes

        return START_STICKY
    }

    private fun startAlarmService(id: Int, notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                id,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(id, notification)
        }
    }

    private fun unsaveAlarm(id: Int) {
        AlarmStorage(this).unsaveAlarm(id)
        AlarmPlugin.alarmTriggerApi?.alarmStopped(id.toLong()) {
            Log.d("AlarmService", "Flutter was notified that alarm $id was stopped.")
        }
        stopAlarm(id)
    }

    private fun stopAlarm(id: Int) {
        AlarmRingingLiveData.instance.update(false)
        try {
            val playingIds = audioService?.getPlayingMediaPlayersIds() ?: listOf()
            ringingAlarmIds = playingIds

            // Safely call methods on 'volumeService' and 'audioService'
            volumeService?.restorePreviousVolume(showSystemUI)
            volumeService?.abandonAudioFocus()

            audioService?.stopAudio(id)

            // Check if media player is empty safely
            if (audioService?.isMediaPlayerEmpty() == true) {
                vibrationService?.stopVibrating()
                stopSelf()
            }

            stopForeground(true)
        } catch (e: IllegalStateException) {
            Log.e("AlarmService", "Illegal State: ${e.message}", e)
        } catch (e: Exception) {
            Log.e("AlarmService", "Error in stopping alarm: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        ringingAlarmIds = listOf()

        audioService?.cleanUp()
        vibrationService?.stopVibrating()
        volumeService?.restorePreviousVolume(showSystemUI)
        volumeService?.abandonAudioFocus()

        AlarmRingingLiveData.instance.update(false)

        stopForeground(true)

        // Call the superclass method
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
