package com.gdelataillade.alarm.alarm

import com.gdelataillade.alarm.services.AudioService
import com.gdelataillade.alarm.services.VibrationService
import com.gdelataillade.alarm.services.VolumeService

import android.app.Service
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.os.IBinder
import android.os.PowerManager
import io.flutter.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.FlutterEngine

class AlarmService : Service() {
    private var channel: MethodChannel? = null
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

        try {
            val messenger = AlarmPlugin.binaryMessenger
            if (messenger != null) {
                channel = MethodChannel(messenger, "com.gdelataillade.alarm/alarm")
            }
        } catch (e: Exception) {
            Log.d("AlarmService", "Error while creating method channel: $e")
        }

        audioService = AudioService(this)
        vibrationService = VibrationService(this)
        volumeService = VolumeService(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
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
        val fullScreenIntent = intent?.getBooleanExtra("fullScreenIntent", true)
        showSystemUI = intent?.getBooleanExtra("showSystemUI", true) ?: true

        // Log.d("AlarmService", "id: $id")
        // Log.d("AlarmService", "assetAudioPath: $assetAudioPath")
        // Log.d("AlarmService", "loopAudio: $loopAudio")
        // Log.d("AlarmService", "vibrate: $vibrate")
        // Log.d("AlarmService", "volume: $volume")
        // Log.d("AlarmService", "fadeDuration: $fadeDuration")
        // Log.d("AlarmService", "notificationTitle: $notificationTitle")
        // Log.d("AlarmService", "notificationBody: $notificationBody")
        // Log.d("AlarmService", "fullScreenIntent: $fullScreenIntent")

        val notificationHandler = NotificationHandler(this)

        val intent = applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
        val pendingIntent = PendingIntent.getActivity(this, id!!, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val notification = notificationHandler.buildNotification(notificationTitle!!, notificationBody!!, fullScreenIntent!!, pendingIntent)
        startForeground(id, notification)

        try {
            if (channel != null) {
                channel?.invokeMethod("alarmRinging", mapOf("id" to id))
            }
        } catch (e: Exception) {
            Log.d("AlarmService", "Error while invoking alarmRinging channel: $e")
        }

        if (volume >= 0.0 && volume <= 1.0) {
            volumeService?.setVolume(volume, showSystemUI)
        }

        volumeService?.requestAudioFocus()

        audioService?.playAudio(id, assetAudioPath!!, loopAudio!!, fadeDuration!!)

        ringingAlarmIds = audioService?.getPlayingMediaPlayersIds()!!

        if (vibrate!!) {
            vibrationService?.startVibrating(longArrayOf(0, 500, 500), 1)
        }

        // Wake up the device
        val wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "app:AlarmWakelockTag")
        wakeLock.acquire(5 * 60 * 1000L) // 5 minutes

        return START_STICKY
    }

    fun stopAlarm(id: Int) {
        ringingAlarmIds = audioService?.getPlayingMediaPlayersIds()!!

        volumeService?.restorePreviousVolume(showSystemUI)
        volumeService?.abandonAudioFocus()

        audioService?.stopAudio(id)
        if (audioService?.isMediaPlayerEmpty()!!) {
            vibrationService?.stopVibrating()
            stopSelf()
        }

        stopForeground(true)
    }

    override fun onDestroy() {
        ringingAlarmIds = listOf()

        audioService?.cleanUp()
        vibrationService?.stopVibrating()
        volumeService?.restorePreviousVolume(showSystemUI)

        stopForeground(true)

        // Call the superclass method
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
