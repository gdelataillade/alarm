package com.gdelataillade.alarm.models

import AlarmSettingsWire
import kotlinx.serialization.KSerializer
import java.util.Date
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder

@Serializable
data class AlarmSettings(
    val id: Int,
    @Serializable(with = DateSerializer::class)
    val dateTime: Date,
    val assetAudioPath: String,
    val volumeSettings: VolumeSettings,
    val notificationSettings: NotificationSettings,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val warningNotificationOnKill: Boolean,
    val androidFullScreenIntent: Boolean
) {
    companion object {
        fun fromWire(e: AlarmSettingsWire): AlarmSettings {
            return AlarmSettings(
                e.id.toInt(),
                Date(e.millisecondsSinceEpoch),
                e.assetAudioPath,
                VolumeSettings.fromWire(e.volumeSettings),
                NotificationSettings.fromWire(e.notificationSettings),
                e.loopAudio,
                e.vibrate,
                e.warningNotificationOnKill,
                e.androidFullScreenIntent,
            )
        }
    }
}

object DateSerializer : KSerializer<Date> {
    override val descriptor = PrimitiveSerialDescriptor("Date", PrimitiveKind.LONG)
    override fun serialize(encoder: Encoder, value: Date) = encoder.encodeLong(value.time)
    override fun deserialize(decoder: Decoder): Date = Date(decoder.decodeLong())
}
