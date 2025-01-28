package com.gdelataillade.alarm.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.gdelataillade.alarm.services.AlarmStorage
import com.gdelataillade.alarm.api.AlarmApiImpl

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Device rebooted, rescheduling alarms")

            rescheduleAlarms(context)
        }
    }

    private fun rescheduleAlarms(context: Context) {
        val alarmStorage = AlarmStorage(context)
        val storedAlarms = alarmStorage.getSavedAlarms()

        Log.i(TAG, "Rescheduling ${storedAlarms.size} alarms")

        for (alarm in storedAlarms) {
            try {
                Log.d(TAG, "Rescheduling alarm with ID: ${alarm.id}")
                Log.d(TAG, "Alarm details: $alarm")

                // Call the setAlarm method in AlarmPlugin with the custom context
                val alarmApi = AlarmApiImpl(context)
                alarmApi.setAlarm(alarm)
                Log.d(TAG, "Alarm rescheduled successfully for ID: ${alarm.id}")
            } catch (e: Exception) {
                Log.e(TAG, "Exception while rescheduling alarm: $alarm", e)
            }
        }
    }
}