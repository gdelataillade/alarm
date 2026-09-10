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
import com.gdelataillade.alarm.models.AlarmEventCause
import com.gdelataillade.alarm.models.AlarmEventVerb
import com.gdelataillade.alarm.models.AlarmSettings
import com.gdelataillade.alarm.models.HostAlarmEvent
import com.gdelataillade.alarm.models.NotificationSettings
import com.gdelataillade.alarm.services.AlarmRingingLiveData
import com.gdelataillade.alarm.services.AlarmScheduler
import java.util.Date
import com.gdelataillade.alarm.services.NotificationHandler
import com.gdelataillade.alarm.services.WarningNotificationState
import com.gdelataillade.alarm.services.SnoozeCoordinator
import io.flutter.Log
import kotlinx.serialization.json.Json

class AlarmService : Service() {
    companion object {
        private const val TAG = "AlarmService"

        // Arbitrary non-zero id used when the service must enter the
        // foreground without a real alarm notification to show.
        private const val PLACEHOLDER_NOTIFICATION_ID = 973_422

        /**
         * How far out to re-arm a ring the platform refused to let us start.
         *
         * Android 15 forbids starting a `mediaPlayback` foreground service from
         * `BOOT_COMPLETED`, and the restriction follows the attribution: while
         * the boot allowlist is open — 20s from when `BootReceiver` runs — every
         * foreground service start by the app inherits it, including one an
         * ordinary `AlarmManager` delivery triggered. Waiting the window out and
         * letting `AlarmManager` deliver again gets the start attributed to the
         * exact-alarm exemption instead, which is allowed.
         *
         * 30s rather than 20s so a slow boot cannot land the retry back inside
         * the window it is trying to escape.
         */
        private const val RING_RETRY_DELAY_MILLIS = 30_000L

        /**
         * Action an application declares on the activity that should present a
         * ringing alarm.
         *
         * Declaring one takes ownership of the alarm surface, so it can be a
         * dedicated activity in its own task that shows over the lock screen
         * and finishes when the alarm is resolved, the way platform clock
         * applications behave. Without it the launcher activity is opened,
         * which is the existing behaviour.
         */
        const val ACTION_RING = "com.gdelataillade.alarm.action.RING"

        /**
         * Whether a delivery still describes the alarm that is stored.
         *
         * `AlarmScheduler.schedule` writes the same settings to storage and into the
         * intent extras in one call, so a mismatch means the delivery is out of date:
         * either the alarm was stopped, or it was re-armed for a different time and this
         * is the superseded arming. A sub-5s alarm is armed with an uncancellable
         * `Handler.postDelayed`, which is how one outlives its own cancellation (#440).
         *
         * Not "stale": #418 uses that for an alarm too late to be worth ringing, which is
         * a different question with a configurable window.
         */
        internal fun isCurrentDelivery(
            delivered: AlarmSettings,
            stored: AlarmSettings?,
        ): Boolean = stored != null && stored.dateTime.time == delivered.dateTime.time

        /** Alarm id, so the activity can act on the alarm it presents. */
        const val EXTRA_ALARM_ID = "alarmId"

        /** Notification title, body and stop label, already localized. */
        const val EXTRA_ALARM_TITLE = "alarmTitle"
        const val EXTRA_ALARM_BODY = "alarmBody"
        const val EXTRA_ALARM_STOP_LABEL = "alarmStopLabel"

        /**
         * Snooze label, already localized, or null when this alarm cannot be
         * snoozed.
         *
         * Gated on the same condition as the notification's snooze action, so
         * an activity can offer snooze exactly when the notification would.
         */
        const val EXTRA_ALARM_SNOOZE_LABEL = "alarmSnoozeLabel"

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

        if (!isCurrentDelivery(alarmSettings, alarmStorage?.getSavedAlarms()?.find { it.id == id })) {
            Log.d(TAG, "Ignoring out-of-date delivery for alarm $id; it was stopped or re-armed.")
            // Arrived via startForegroundService, so the obligation stands even though
            // nothing will ring.
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
        val pendingIntent = ringPendingIntent(id, alarmSettings)

        val notification = notificationHandler.buildNotification(
            alarmSettings.notificationSettings,
            alarmSettings.androidFullScreenIntent,
            pendingIntent,
            id,
            alarmSettings.canSnooze
        )

        // Start the service in the foreground
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                try {
                    startAlarmService(id, notification)
                } catch (e: ForegroundServiceStartNotAllowedException) {
                    // Returning here is what made the alarm vanish in silence:
                    // the service stays up, never foregrounded, with no
                    // notification and no audio, and nothing tells Dart.
                    Log.e(TAG, "Foreground service start not allowed; deferring the ring", e)
                    deferRefusedRing(id, alarmSettings)
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

        // Enforcement belongs to the ring that asked for it. An alarm with no volume
        // never reaches setVolume, so stop the previous one's here too (#444).
        volumeService?.stopVolumeEnforcement()

        // Set the volume if specified
        if (alarmSettings.volumeSettings.volume != null) {
            volumeService?.setVolume(
                alarmSettings.volumeSettings.volume,
                alarmSettings.volumeSettings.volumeEnforced,
                showSystemUI,
                alarmSettings.preferConnectedAudioDevice
            )
        } else if (alarmSettings.volumeSettings.volumeEnforced) {
            // Enforced with no volume: protect the user's own level rather than replace it.
            volumeService?.enforceCurrentVolume(
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
                // An alarm that is currently ringing does not need a kill
                // warning. If it is snoozed rather than stopped, rescheduling
                // restores the warning via WarningNotificationState.refresh.
                WarningNotificationState.disable(this)
                Log.d(TAG, "Turning off the warning notification.")
            } else {
                Log.d(TAG, "Keeping the warning notification on because there are other pending alarms.")
            }
        }
    }

    /**
     * The activity a full-screen intent opens for [id].
     *
     * Everything the surface needs to present the alarm travels in the intent,
     * so it can render without a Flutter engine. That is the normal case: the
     * process is started by the full-screen intent itself, which does not
     * start Flutter.
     */
    private fun ringPendingIntent(id: Int, alarmSettings: AlarmSettings): PendingIntent {
        val ringIntent = resolveRingIntent()?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra(EXTRA_ALARM_ID, id)
            putExtra(EXTRA_ALARM_TITLE, alarmSettings.notificationSettings.title)
            putExtra(EXTRA_ALARM_BODY, alarmSettings.notificationSettings.body)
            putExtra(EXTRA_ALARM_STOP_LABEL, alarmSettings.notificationSettings.stopButton)
            putExtra(
                EXTRA_ALARM_SNOOZE_LABEL,
                alarmSettings.notificationSettings.androidSnoozeButton
                    ?.takeIf { alarmSettings.canSnooze }
            )
        } ?: applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)
            ?: Intent()

        return PendingIntent.getActivity(
            this,
            id,
            ringIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    /** The application's own alarm activity, or null when it declares none. */
    private fun resolveRingIntent(): Intent? {
        val intent = Intent(ACTION_RING).setPackage(applicationContext.packageName)
        val matches = applicationContext.packageManager.queryIntentActivities(intent, 0)
        if (matches.size > 1) {
            Log.w(TAG, "${matches.size} activities handle $ACTION_RING; using the first.")
        }
        val resolved = matches.firstOrNull() ?: return null
        return intent.setClassName(
            resolved.activityInfo.packageName,
            resolved.activityInfo.name
        )
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

    /**
     * Re-arms [alarmSettings] shortly in the future after the platform refused to
     * let this ring enter the foreground.
     *
     * The refusal is not the alarm's fault and not recoverable in the moment, so
     * the only honest options are to lose the alarm or to ring it late. Late is
     * better: an alarm that sounds 30 seconds after a reboot is a far smaller
     * failure than one that never sounds at all.
     *
     * Goes through [AlarmScheduler] so the shifted time is persisted as well as
     * armed. That matters because Dart's reconciliation stops any alarm it finds
     * past due, so a retry armed without moving the stored time would be
     * cancelled by the next `Alarm.init()`.
     */
    private fun deferRefusedRing(alarmId: Int, alarmSettings: AlarmSettings) {
        val storage = AlarmStorage(this)

        // One retry is enough by construction: the boot allowlist lasts about
        // 20s from when `BootReceiver` runs and the retry is armed 30s out, so
        // it lands outside the window. A second refusal means the boot window
        // was never the cause, and deferring again would postpone the same
        // failure forever — 30s at a time, with the user hearing nothing.
        //
        // The check has to be durable rather than a counter on this class. By
        // the time the retry fires, 30s later, this process holds no foreground
        // service — the refused one stopped itself — so it is an ordinary
        // background process the system may reclaim at any moment, and boot is
        // when it is most likely to. In-memory state would then reset between a
        // refusal and its own retry and never reach the limit. The marker the
        // first deferral wrote is what survives that.
        val alreadyDeferred = storage.getPendingAlarmEvents().any {
            it.alarmId == alarmId &&
                it.verb == AlarmEventVerb.MOVED &&
                it.cause == AlarmEventCause.PLATFORM_REFUSAL
        }
        if (alreadyDeferred) {
            dropRefusedRing(alarmId, alarmSettings, storage)
            return
        }

        val recordedAt = System.currentTimeMillis()
        val retryAt = recordedAt + RING_RETRY_DELAY_MILLIS
        val deferred = alarmSettings.copy(dateTime = Date(retryAt))
        val event = HostAlarmEvent(
            alarmId = alarmId,
            verb = AlarmEventVerb.MOVED,
            cause = AlarmEventCause.PLATFORM_REFUSAL,
            atMillis = retryAt,
            recordedAtMillis = recordedAt,
        )

        // Recorded before arming, the same ordering SnoozeCoordinator uses: a
        // crash in between still leaves Dart able to learn the alarm moved, and
        // without that its reconciliation stops the alarm and cancels the retry.
        storage.saveAlarmEvent(event)

        if (!AlarmScheduler.schedule(this, deferred, requireDurable = true)) {
            // The marker now describes a retry that is not armed.
            storage.clearAlarmEvent(alarmId)
            Log.e(TAG, "Could not re-arm the refused ring for $alarmId.")
            dropRefusedRing(alarmId, alarmSettings, storage)
            return
        }

        Log.d(TAG, "Ring for $alarmId deferred to $retryAt after a refused foreground start.")
        reportHostEvent(event)

        // Nothing is ringing, so leave no service behind holding a foreground
        // obligation it was never allowed to meet.
        stopSelfIfIdle()
    }

    /**
     * Gives up on a ring the platform will not allow, and says so.
     *
     * Reached when a retry is refused too, which means waiting out the boot
     * window was not the answer. The alarm cannot ring and nothing here can make
     * it, so the choice is between losing it silently and losing it visibly.
     * Recording a drop is what lets the application tell its user that an alarm
     * they set did not go off — the plugin deliberately says nothing itself.
     */
    private fun dropRefusedRing(
        alarmId: Int,
        alarmSettings: AlarmSettings,
        storage: AlarmStorage,
    ) {
        val event = HostAlarmEvent(
            alarmId = alarmId,
            verb = AlarmEventVerb.DROPPED,
            cause = AlarmEventCause.PLATFORM_REFUSAL,
            atMillis = alarmSettings.dateTime.time,
            recordedAtMillis = System.currentTimeMillis(),
        )

        // Order is free here: unsaveAlarm deliberately keeps DROPPED markers, so
        // the record survives the removal it describes.
        storage.saveAlarmEvent(event)
        storage.unsaveAlarm(alarmId)

        Log.e(
            TAG,
            "Ring for $alarmId was refused again; dropping the alarm and reporting it."
        )
        reportHostEvent(event)
        stopSelfIfIdle()
    }

    /**
     * Tells Dart about [event] if an engine happens to be attached.
     *
     * Usually there is none — these refusals happen at boot — so the durable
     * marker is the real delivery path and this is only an optimisation.
     *
     * Deliberately does not drop the marker on a successful reply. This call
     * returning means Dart *emitted* the event, not that anything has finished
     * with it, so acknowledging here would delete the durable record while an
     * application handler is still writing the event down — the same hole the
     * drain had. Dart acknowledges instead, once whoever owns that boundary
     * says so; see `Alarm.acknowledgeEvent`.
     */
    private fun reportHostEvent(event: HostAlarmEvent) {
        AlarmPlugin.alarmTriggerApi?.alarmEvent(event.toWire()) { result ->
            if (result.isFailure) {
                Log.d(TAG, "Dart did not apply the event for ${event.alarmId}; keeping the marker.")
            }
        }
    }

    /**
     * Re-posts the ring notification for [alarmId] after the user swiped it away.
     *
     * Only for [AlarmReceiver], and only reached when the alarm set
     * `androidStopAlarmOnDismiss = false`. Dismissing a foreground service
     * notification does not stop the service, so without this the alarm keeps
     * sounding with nothing on screen to act on it.
     *
     * Does nothing unless this service is currently ringing [alarmId] and owns its
     * notification, so a dismissal that races the alarm ending cannot resurrect a
     * notification for an alarm that is over. That guard also matters because
     * [AlarmReceiver] is exported and the action can therefore be broadcast by
     * anything.
     */
    fun restoreNotification(alarmId: Int) {
        if (!ringingAlarmIds.contains(alarmId)) {
            Log.d(TAG, "Not restoring the notification for $alarmId: it is not ringing.")
            return
        }

        val notification = currentForegroundNotification
        if (currentForegroundId != alarmId || notification == null) {
            Log.d(TAG, "Not restoring the notification for $alarmId: this service does not own it.")
            return
        }

        // Re-posted through startForeground rather than the notification manager so
        // the notification stays owned by the service, and stopForeground still
        // removes it when the alarm ends.
        startAlarmService(alarmId, notification)
        Log.d(TAG, "Restored the ring notification for $alarmId after a dismissal.")
    }

    /**
     * Silences [alarmId] without unsaving it or telling Flutter it stopped.
     *
     * Only for [SnoozeCoordinator], and only once it has armed the replacement:
     * the alarm is still owed, so none of the stop bookkeeping applies.
     */
    /** Stops [alarmId]'s audio and dequeues it, touching neither storage nor Flutter. */
    fun silenceRing(alarmId: Int) {
        stopAlarm(alarmId)
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
                val stored = alarmStorage?.getSavedAlarms()?.find { it.id == nextId }
                if (isCurrentDelivery(nextSettings, stored)) {
                    Log.d(TAG, "Triggering queued alarm $nextId.")
                    ringAlarm(nextId, nextSettings)
                    return
                } else {
                    Log.d(TAG, "Queued alarm $nextId was stopped or re-armed while waiting, skipping.")
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
