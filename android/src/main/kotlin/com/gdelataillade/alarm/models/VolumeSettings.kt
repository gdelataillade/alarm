package com.gdelataillade.alarm.models

import VolumeFadeStepWire
import VolumeSettingsWire
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds

data class VolumeSettings(
    val volume: Double?,
    val fadeDuration: Duration?,
    val fadeSteps: List<VolumeFadeStep>,
    val volumeEnforced: Boolean
) {
    companion object {
        fun fromWire(e: VolumeSettingsWire): VolumeSettings {
            return VolumeSettings(
                e.volume,
                e.fadeDurationMillis?.milliseconds,
                e.fadeSteps.map { VolumeFadeStep.fromWire(it) },
                e.volumeEnforced,
            )
        }
    }
}

data class VolumeFadeStep(
    val time: Duration,
    val volume: Double
) {
    companion object {
        fun fromWire(e: VolumeFadeStepWire): VolumeFadeStep {
            return VolumeFadeStep(
                e.timeMillis.milliseconds,
                e.volume,
            )
        }
    }
}