package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.AudioService
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.services.VibrationService
import com.gdelataillade.alarm.services.VolumeService

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
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.services.AlarmRingingLiveData
import com.gdelataillade.alarm.services.NotificationHandler
import com.gdelataillade.alarm.services.NotificationOnKillService
import io.flutter.Log
import kotlinx.serialization.json.Json

class AlarmService : Service() {
    companion object {
        private const val TAG = "AlarmService"

        var instance: AlarmService? = null

        @JvmStatic
        var ringingAlarmIds: List<Int> = listOf()
    }

    private var alarmId: Int = 0
    private var audioService: AudioService? = null
    private var vibrationService: VibrationService? = null
    private var volumeService: VolumeService? = null
    private var alarmStorage: AlarmStorage? = null
    private var showSystemUI: Boolean = true
    private var shouldStopAlarmOnTermination: Boolean = true

    override fun onCreate() {
        super.onCreate()

        instance = this
        audioService = AudioService(this)
        vibrationService = VibrationService(this)
        volumeService = VolumeService(this)
        alarmStorage = AlarmStorage(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val id = intent.getIntExtra("id", 0)
        alarmId = id
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

        val alarmSettingsJson = intent.getStringExtra("alarmSettings")
        if (alarmSettingsJson == null) {
            Log.e(TAG, "Intent is missing AlarmSettings.")
            stopSelf()
            return START_NOT_STICKY
        }

        val alarmSettings: AlarmSettings
        try {
            alarmSettings = Json.decodeFromString<AlarmSettings>(alarmSettingsJson)
        } catch (e: Exception) {
            Log.e(TAG, "Cannot parse AlarmSettings from Intent.")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = notificationHandler.buildNotification(
            alarmSettings.notificationSettings,
            alarmSettings.androidFullScreenIntent,
            pendingIntent,
            id
        )

        // Start the service in the foreground
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    startAlarmService(id, notification)
                } catch (e: ForegroundServiceStartNotAllowedException) {
                    Log.e(TAG, "Foreground service start not allowed", e)
                    return START_NOT_STICKY
                }
            } else {
                startAlarmService(id, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while starting foreground service: ${e.message}", e)
            return START_NOT_STICKY
        }

        // Check if an alarm is already ringing
        if (!alarmSettings.allowAlarmOverlap && ringingAlarmIds.isNotEmpty() && action != "STOP_ALARM") {
            Log.d(TAG, "An alarm is already ringing. Ignoring new alarm with id: $id")
            unsaveAlarm(id)
            return START_NOT_STICKY
        }

        if (alarmSettings.androidFullScreenIntent) {
            AlarmRingingLiveData.instance.update(true)
        }

        // Notify the plugin about the alarm ringing
        AlarmPlugin.alarmTriggerApi?.alarmRang(id.toLong()) {
            if (it.isSuccess) {
                Log.d(TAG, "Alarm rang notification for $id was processed successfully by Flutter.")
            } else {
                Log.d(TAG, "Alarm rang notification for $id encountered error in Flutter.")
            }
        }

        // Set the volume if specified
        if (alarmSettings.volumeSettings.volume != null) {
            volumeService?.setVolume(
                alarmSettings.volumeSettings.volume,
                alarmSettings.volumeSettings.volumeEnforced,
                showSystemUI
            )
        }

        // Request audio focus
        volumeService?.requestAudioFocus()

        // Set up audio completion listener
        audioService?.setOnAudioCompleteListener {
            if (!alarmSettings.loopAudio) {
                vibrationService?.stopVibrating()
                volumeService?.restorePreviousVolume(showSystemUI)
                volumeService?.abandonAudioFocus()
            }
        }

        // Play the alarm audio
        audioService?.playAudio(
            id,
            alarmSettings.assetAudioPath,
            alarmSettings.loopAudio,
            alarmSettings.volumeSettings.fadeDuration,
            alarmSettings.volumeSettings.fadeSteps
        )

        // Update the list of ringing alarms
        ringingAlarmIds = audioService?.getPlayingMediaPlayersIds() ?: listOf()

        // Start vibration if enabled
        if (alarmSettings.vibrate) {
            vibrationService?.startVibrating(longArrayOf(0, 500, 500), 1)
        }

        // Retrieve whether the alarm should be stopped on task termination
        shouldStopAlarmOnTermination = alarmSettings.androidStopAlarmOnTermination

        // Acquire a wake lock to wake up the device
        val wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "app:AlarmWakelockTag")
        wakeLock.acquire(5 * 60 * 1000L) // Acquire for 5 minutes

        // If there are no other alarms scheduled, turn off the warning notification.
        val storage = alarmStorage
        if (storage != null) {
            val storedAlarms = storage.getSavedAlarms()
            if (storedAlarms.isEmpty() || storedAlarms.all { it.id == id }) {
                val serviceIntent = Intent(this, NotificationOnKillService::class.java)
                // If the service isn't running this call will be ignored.
                this.stopService(serviceIntent)
                Log.d(TAG, "Turning off the warning notification.")
            } else {
                Log.d(TAG, "Keeping the warning notification on because there are other pending alarms.")
            }
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "App closed, checking if alarm should be stopped.")

        if (shouldStopAlarmOnTermination) {
            Log.d(TAG, "Stopping alarm as androidStopAlarmOnTermination is true.")
            unsaveAlarm(alarmId)
            stopSelf()
        } else {
            Log.d(TAG, "Keeping alarm running as androidStopAlarmOnTermination is false.")
        }
        
        super.onTaskRemoved(rootIntent)
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

    fun handleStopAlarmCommand(alarmId: Int) {
        if (alarmId == 0) return
        unsaveAlarm(alarmId)
    }

    private fun unsaveAlarm(id: Int) {
        alarmStorage?.unsaveAlarm(id)
        // Notify the plugin about the alarm being stopped.
        AlarmPlugin.alarmTriggerApi?.alarmStopped(id.toLong()) {
            if (it.isSuccess) {
                Log.d(TAG, "Alarm stopped notification for $id was processed successfully by Flutter.")
            } else {
                Log.d(TAG, "Alarm stopped notification for $id encountered error in Flutter.")
            }
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
            Log.e(TAG, "Illegal State: ${e.message}", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error in stopping alarm: ${e.message}", e)
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
        instance = null

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
