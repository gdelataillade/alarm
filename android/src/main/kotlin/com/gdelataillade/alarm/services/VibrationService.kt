package com.gdelataillade.alarm.services

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

class VibrationService(private val context: Context) {
    private var vibrator: Vibrator? = null

    fun startVibrating(pattern: LongArray, repeat: Int) {
        if (vibrator == null) {
            vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val vibrationEffect = VibrationEffect.createWaveform(pattern, repeat)
        vibrator?.vibrate(vibrationEffect)
    }

    fun stopVibrating() {
        vibrator?.cancel()
    }
}
