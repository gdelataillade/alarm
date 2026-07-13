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
import androidx.core.app.ServiceCompat
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.NotificationSettings
import com.gdelataillade.alarm.services.AlarmRingingLiveData
import com.gdelataillade.alarm.services.NotificationHandler
import com.gdelataillade.alarm.services.NotificationOnKillService
import io.flutter.Log
import kotlinx.serialization.json.Json

class AlarmService : Service() {
    companion object {
        private const val TAG = "AlarmService"

        // Arbitrary non-zero id used when the service must enter the
        // foreground without a real alarm notification to show.
        private const val PLACEHOLDER_NOTIFICATION_ID = 973_422

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
    private val ringingQueue = mutableListOf<Int>()
    private val queuedAlarmSettings = mutableMapOf<Int, AlarmSettings>()

    // Last notification passed to startForeground, so no-op start commands
    // (queued or ignored alarms) can re-post it to satisfy the
    // startForegroundService() contract without any visible change.
    private var currentForegroundId: Int? = null
    private var currentForegroundNotification: Notification? = null

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
            // Sticky restart after process death: there is no alarm state to
            // restore from the intent, shut down quietly. This start did not
            // come from startForegroundService(), so there is no
            // startForeground() obligation.
            stopSelfIfIdle()
            return START_NOT_STICKY
        }

        // Note: `alarmId` is only updated in ringAlarm() so that queued or
        // stopped alarms never overwrite the id of the currently ringing
        // alarm, which onTaskRemoved relies on.
        val id = intent.getIntExtra("id", 0)

        val alarmSettingsJson = intent.getStringExtra("alarmSettings")
        if (alarmSettingsJson == null) {
            Log.e(TAG, "Intent is missing AlarmSettings.")
            fulfillForegroundObligation()
            stopSelfIfIdle()
            return START_NOT_STICKY
        }

        val alarmSettings: AlarmSettings
        try {
            alarmSettings = Json.decodeFromString<AlarmSettings>(alarmSettingsJson)
        } catch (e: Exception) {
            Log.e(TAG, "Cannot parse AlarmSettings from Intent.", e)
            fulfillForegroundObligation()
            stopSelfIfIdle()
            return START_NOT_STICKY
        }

        // If another alarm is already ringing
        if (!alarmSettings.allowAlarmOverlap && ringingAlarmIds.isNotEmpty()) {
            // The service is already in the foreground for the ringing alarm;
            // re-post its notification so this start command also fulfills
            // the startForegroundService() contract.
            fulfillForegroundObligation()
            if (alarmSettings.allowSameSecondScheduling) {
                // Queue for sequential ringing (like iOS system Clock app)
                ringingQueue.add(id)
                queuedAlarmSettings[id] = alarmSettings
                Log.d(TAG, "Alarm $id queued because another alarm is already ringing.")
            } else {
                Log.d(TAG, "An alarm is already ringing. Ignoring new alarm with id: $id")
                unsaveAlarm(id)
            }
            return START_NOT_STICKY
        }

        ringAlarm(id, alarmSettings)
        return START_STICKY
    }

    private fun ringAlarm(id: Int, alarmSettings: AlarmSettings) {
        alarmId = id

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
                    return
                }
            } else {
                startAlarmService(id, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while starting foreground service: ${e.message}", e)
            return
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

        // Read showSystemUI before any volume calls that depend on it
        showSystemUI = alarmSettings.volumeSettings.showSystemUI

        // Set the volume if specified
        if (alarmSettings.volumeSettings.volume != null) {
            volumeService?.setVolume(
                alarmSettings.volumeSettings.volume,
                alarmSettings.volumeSettings.volumeEnforced,
                showSystemUI,
                alarmSettings.preferConnectedAudioDevice
            )
        }

        // Request audio focus
        volumeService?.requestAudioFocus(alarmSettings.preferConnectedAudioDevice)

        // Set up audio completion listener
        audioService?.setOnAudioCompleteListener(id) {
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
            alarmSettings.volumeSettings.fadeSteps,
            alarmSettings.preferConnectedAudioDevice
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
        currentForegroundId = id
        currentForegroundNotification = notification
    }

    /// Matches a startForegroundService() call with the mandatory
    /// startForeground() call, even when the command turns out to be a no-op.
    /// Missing this contract crashes the app on Android 8+ with
    /// "Context.startForegroundService() did not then call startForeground()".
    private fun fulfillForegroundObligation() {
        try {
            val id = currentForegroundId
            val notification = currentForegroundNotification
            if (id != null && notification != null) {
                // Re-posting the same notification is invisible to the user.
                startAlarmService(id, notification)
                return
            }

            // Fresh service instance with nothing to show: post a minimal
            // placeholder. The caller stops the service right after, which
            // removes it again.
            val appIntent =
                applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                appIntent ?: Intent(),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val placeholder = NotificationHandler(this).buildNotification(
                NotificationSettings(title = "Alarm", body = ""),
                false,
                pendingIntent,
                0
            )
            startAlarmService(PLACEHOLDER_NOTIFICATION_ID, placeholder)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fulfill the foreground service contract", e)
        }
    }

    /// Stops the service only when no alarm is ringing, so an invalid start
    /// command can never kill an in-progress alarm.
    private fun stopSelfIfIdle() {
        if (ringingAlarmIds.isEmpty()) {
            stopSelf()
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
        try {
            audioService?.stopAudio(id)

            // Remove from queue if present so stopped alarms never get promoted
            ringingQueue.remove(id)
            queuedAlarmSettings.remove(id)

            val playingIds = audioService?.getPlayingMediaPlayersIds() ?: listOf()
            ringingAlarmIds = playingIds

            if (playingIds.isEmpty()) {
                triggerNextQueuedAlarm()

                if (ringingAlarmIds.isEmpty()) {
                    // No more queued alarms, perform full cleanup
                    AlarmRingingLiveData.instance.update(false)
                    volumeService?.restorePreviousVolume(showSystemUI)
                    volumeService?.abandonAudioFocus()
                    vibrationService?.stopVibrating()
                    ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                    currentForegroundId = null
                    currentForegroundNotification = null
                    stopSelf()
                }
            }
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Illegal State: ${e.message}", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error in stopping alarm: ${e.message}", e)
        }
    }

    private fun triggerNextQueuedAlarm() {
        while (ringingQueue.isNotEmpty()) {
            // FIFO: the alarm that was queued first rings first, matching the
            // documented sequential behavior.
            val nextId = ringingQueue.removeAt(0)
            val nextSettings = queuedAlarmSettings.remove(nextId)
            if (nextSettings != null) {
                // Validate the alarm still exists in storage before promoting
                val savedAlarms = alarmStorage?.getSavedAlarms() ?: listOf()
                if (savedAlarms.any { alarm -> alarm.id == nextId }) {
                    Log.d(TAG, "Triggering queued alarm $nextId.")
                    ringAlarm(nextId, nextSettings)
                    return
                } else {
                    Log.d(TAG, "Queued alarm $nextId no longer exists in storage, skipping.")
                }
            }
        }
    }

    override fun onDestroy() {
        ringingAlarmIds = listOf()
        ringingQueue.clear()
        queuedAlarmSettings.clear()

        audioService?.cleanUp()
        vibrationService?.stopVibrating()
        volumeService?.restorePreviousVolume(showSystemUI)
        volumeService?.abandonAudioFocus()

        AlarmRingingLiveData.instance.update(false)

        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        currentForegroundId = null
        currentForegroundNotification = null
        instance = null

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
