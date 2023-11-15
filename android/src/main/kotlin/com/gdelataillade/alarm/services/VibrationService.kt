package com.gdelataillade.alarm.services

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

class VibrationService(private val context: Context) {
    private val vibrator: Vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

    fun startVibrating(pattern: LongArray, repeat: Int) {
        val vibrationEffect = VibrationEffect.createWaveform(pattern, repeat)
        vibrator.vibrate(vibrationEffect)
    }

    fun stopVibrating() {
        vibrator.cancel()
    }
}
