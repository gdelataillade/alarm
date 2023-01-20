package com.gdelataillade.alarm.alarm

import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/// Communication between Flutter Alarm service and native Android.
class AlarmPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var context: Context
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
      context = flutterPluginBinding.applicationContext
      channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.gdelataillade.alarm/notifOnAppKill")
      channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
        "setNotificationOnKillService" -> {
          val title = call.argument<String>("title")
          val description = call.argument<String>("description")

          val serviceIntent = Intent(context, NotificationOnKillService::class.java)

          serviceIntent.putExtra("title", title)
          serviceIntent.putExtra("description", description)

          context.startService(serviceIntent)
          result.success(true)
        }
        "stopNotificationOnKillService" -> {
          val serviceIntent = Intent(context, NotificationOnKillService::class.java)
          context.stopService(serviceIntent)
          result.success(true)
        }
        else -> {
            result.notImplemented()
        }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
