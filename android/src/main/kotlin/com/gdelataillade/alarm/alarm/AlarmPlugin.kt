package com.gdelataillade.alarm.alarm

import AlarmApi
import AlarmTriggerApi
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.Observer
import com.gdelataillade.alarm.api.AlarmApiImpl
import com.gdelataillade.alarm.services.AlarmRingingLiveData
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class AlarmPlugin : FlutterPlugin, ActivityAware {
    private var activity: Activity? = null

    companion object {
        @JvmStatic
        var alarmTriggerApi: AlarmTriggerApi? = null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AlarmApi.setUp(binding.binaryMessenger, AlarmApiImpl(binding.applicationContext))
        alarmTriggerApi = AlarmTriggerApi(binding.binaryMessenger)

    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        alarmTriggerApi = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        AlarmRingingLiveData.instance.observe(
            binding.activity as LifecycleOwner,
            notificationObserver
        )
    }

    override fun onDetachedFromActivity() {
        activity = null
        AlarmRingingLiveData.instance.removeObserver(notificationObserver)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    private val notificationObserver = Observer<Boolean> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
            Log.w("AlarmPlugin", "Making app visible on lock screen is not supported on this version of Android.")
            return@Observer
        }
        val activity = activity ?: return@Observer
        if (it) {
            Log.d("AlarmPlugin", "Making app visible on lock screen...")
            activity.setShowWhenLocked(true)
            activity.setTurnScreenOn(true)
            val keyguardManager =
                activity.applicationContext.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(activity, null)
        } else {
            Log.d("AlarmPlugin", "Reverting making app visible on lock screen...")
            activity.setShowWhenLocked(false)
            activity.setTurnScreenOn(false)
        }
    }
}
