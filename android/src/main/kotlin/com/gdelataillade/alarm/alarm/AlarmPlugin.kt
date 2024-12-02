package com.gdelataillade.alarm.alarm

import AlarmApi
import AlarmTriggerApi
import com.gdelataillade.alarm.api.AlarmApiImpl
import io.flutter.embedding.engine.plugins.FlutterPlugin

class AlarmPlugin : FlutterPlugin {
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
}
