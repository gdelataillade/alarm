package com.gdelataillade.alarm.models

import com.gdelataillade.alarm.generated.AlarmSettingsWire
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.*
import java.time.Duration
import kotlin.time.toKotlinDuration
import java.util.Date

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
    val androidFullScreenIntent: Boolean,
    val allowAlarmOverlap: Boolean = false, // Defaults to false for backward compatibility
    val androidStopAlarmOnTermination: Boolean = true, // Defaults to true for backward compatibility
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
                e.allowAlarmOverlap,
                e.androidStopAlarmOnTermination,
            )
        }

        /**
         * Handles backward compatibility for missing fields like `volumeSettings` and `allowAlarmOverlap`.
         */
        fun fromJson(json: String): AlarmSettings {
            val jsonObject = Json.parseToJsonElement(json).jsonObject

            val id = jsonObject.primitiveInt("id") ?: throw SerializationException("Missing 'id'")
            val dateTimeMillis = jsonObject.primitiveLong("dateTime") ?: throw SerializationException("Missing 'dateTime'")
            val assetAudioPath = jsonObject.primitiveString("assetAudioPath") ?: throw SerializationException("Missing 'assetAudioPath'")
            val notificationSettings = jsonObject["notificationSettings"]?.let {
                Json.decodeFromJsonElement(NotificationSettings.serializer(), it)
            } ?: throw SerializationException("Missing 'notificationSettings'")
            val loopAudio = jsonObject.primitiveBoolean("loopAudio") ?: throw SerializationException("Missing 'loopAudio'")
            val vibrate = jsonObject.primitiveBoolean("vibrate") ?: throw SerializationException("Missing 'vibrate'")
            val warningNotificationOnKill = jsonObject.primitiveBoolean("warningNotificationOnKill")
                ?: throw SerializationException("Missing 'warningNotificationOnKill'")
            val androidFullScreenIntent = jsonObject.primitiveBoolean("androidFullScreenIntent")
                ?: throw SerializationException("Missing 'androidFullScreenIntent'")

            // Handle backward compatibility for `allowAlarmOverlap`
            val allowAlarmOverlap = jsonObject.primitiveBoolean("allowAlarmOverlap") ?: false

            // Handle backward compatibility for `androidStopAlarmOnTermination`
            val androidStopAlarmOnTermination = jsonObject.primitiveBoolean("androidStopAlarmOnTermination") ?: true

            // Handle backward compatibility for `volumeSettings`
            val volumeSettings = jsonObject["volumeSettings"]?.let {
                Json.decodeFromJsonElement(VolumeSettings.serializer(), it)
            } ?: run {
                val volume = jsonObject.primitiveDouble("volume")
                val fadeDurationSeconds = jsonObject.primitiveDouble("fadeDuration")
                val fadeDuration = fadeDurationSeconds?.let { Duration.ofMillis((it * 1000).toLong()) }
                val volumeEnforced = jsonObject.primitiveBoolean("volumeEnforced") ?: false

                VolumeSettings(
                    volume = volume,
                    fadeDuration = fadeDuration?.toKotlinDuration(),
                    fadeSteps = emptyList(), // No equivalent for older models
                    volumeEnforced = volumeEnforced
                )
            }

            return AlarmSettings(
                id = id,
                dateTime = Date(dateTimeMillis),
                assetAudioPath = assetAudioPath,
                volumeSettings = volumeSettings,
                notificationSettings = notificationSettings,
                loopAudio = loopAudio,
                vibrate = vibrate,
                warningNotificationOnKill = warningNotificationOnKill,
                androidFullScreenIntent = androidFullScreenIntent,
                allowAlarmOverlap = allowAlarmOverlap,
                androidStopAlarmOnTermination = androidStopAlarmOnTermination,
            )
        }
    }
}

/**
 * Custom serializer for Java's `Date` type.
 */
object DateSerializer : KSerializer<Date> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("Date", PrimitiveKind.LONG)
    override fun serialize(encoder: Encoder, value: Date) = encoder.encodeLong(value.time)
    override fun deserialize(decoder: Decoder): Date = Date(decoder.decodeLong())
}

// Extension functions for safer primitive extraction from JsonObject
private fun JsonObject.primitiveInt(key: String): Int? = this[key]?.jsonPrimitive?.content?.toIntOrNull()
private fun JsonObject.primitiveLong(key: String): Long? = this[key]?.jsonPrimitive?.content?.toLongOrNull()
private fun JsonObject.primitiveDouble(key: String): Double? = this[key]?.jsonPrimitive?.content?.toDoubleOrNull()
private fun JsonObject.primitiveString(key: String): String? = this[key]?.jsonPrimitive?.content
private fun JsonObject.primitiveBoolean(key: String): Boolean? = this[key]?.jsonPrimitive?.content?.toBooleanStrictOrNull()