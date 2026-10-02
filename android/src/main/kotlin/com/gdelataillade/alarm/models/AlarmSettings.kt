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
    val assetAudioPath: String?, // Null means use device default alarm sound
    val volumeSettings: VolumeSettings,
    val notificationSettings: NotificationSettings,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val warningNotificationOnKill: Boolean,
    val androidFullScreenIntent: Boolean,
    val allowAlarmOverlap: Boolean = false, // Defaults to false for backward compatibility
    val allowSameSecondScheduling: Boolean = false, // Defaults to false for backward compatibility
    val androidStopAlarmOnTermination: Boolean = true, // Defaults to true for backward compatibility
    val preferConnectedAudioDevice: Boolean = false, // Defaults to false for backward compatibility
    // Null, or below SNOOZE_MINIMUM_MILLIS, offers no snooze.
    val androidSnoozeDurationMillis: Long? = null,
    // Absent means the default; an explicit null means never discard.
    val androidStaleAfterMillis: Long? = DEFAULT_STALE_AFTER_MILLIS,
    val androidAlarmClock: Boolean = true, // Defaults to true for backward compatibility
) {
    /** Whether this alarm can be deferred rather than only stopped. */
    val canSnooze: Boolean
        get() = (androidSnoozeDurationMillis ?: 0L) >= SNOOZE_MINIMUM_MILLIS

    companion object {
        /**
         * Shortest snooze the platform accepts.
         *
         * Kept above the delay below which scheduling falls back to a plain
         * `Handler.postDelayed` instead of `AlarmManager`: that fallback
         * survives neither process death nor cancellation, so a snooze shorter
         * than this could not be honoured or undone.
         */
        const val SNOOZE_MINIMUM_MILLIS = 60_000L

        /**
         * How long past its due time an alarm found at boot is still worth
         * ringing, when the alarm does not say.
         *
         * Long enough that a reboot straddling the alarm still rings, short
         * enough that a phone switched on hours later stays quiet. Must match
         * `AlarmSettings.defaultStaleAfter` on the Dart side.
         */
        const val DEFAULT_STALE_AFTER_MILLIS = 900_000L

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
                e.allowSameSecondScheduling,
                e.androidStopAlarmOnTermination,
                e.preferConnectedAudioDevice,
                e.androidSnoozeDurationMillis,
                e.androidStaleAfterMillis,
                e.androidAlarmClock,
            )
        }

        /**
         * Handles backward compatibility for missing fields like `volumeSettings` and `allowAlarmOverlap`.
         */
        fun fromJson(json: String): AlarmSettings {
            val jsonObject = Json.parseToJsonElement(json).jsonObject

            val id = jsonObject.primitiveInt("id") ?: throw SerializationException("Missing 'id'")
            val dateTimeMillis = jsonObject.primitiveLong("dateTime") ?: throw SerializationException("Missing 'dateTime'")
            val assetAudioPath = jsonObject.primitiveString("assetAudioPath") // Can be null to use device default
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

            // Handle backward compatibility for `allowSameSecondScheduling`
            val allowSameSecondScheduling = jsonObject.primitiveBoolean("allowSameSecondScheduling") ?: false

            // Handle backward compatibility for `androidStopAlarmOnTermination`
            val androidStopAlarmOnTermination = jsonObject.primitiveBoolean("androidStopAlarmOnTermination") ?: true

            // Handle backward compatibility for `preferConnectedAudioDevice`
            val preferConnectedAudioDevice = jsonObject.primitiveBoolean("preferConnectedAudioDevice") ?: false

            // Absent in alarms saved before snooze existed, which simply means
            // the alarm can only be stopped.
            val androidSnoozeDurationMillis = jsonObject.primitiveLong("androidSnoozeDurationMillis")

            // Three states, which primitiveLong alone cannot tell apart: absent
            // means an alarm saved before the cutoff existed, and takes the
            // default; an explicit null means never discard; anything
            // unparseable falls back to the default rather than dropping the
            // alarm, matching the Dart reader.
            val androidStaleAfterMillis = when (val stale = jsonObject["androidStaleAfterMillis"]) {
                null -> DEFAULT_STALE_AFTER_MILLIS
                JsonNull -> null
                // Cast rather than jsonPrimitive, which throws on an object or
                // an array instead of recovering like the two lines above.
                else -> (stale as? JsonPrimitive)?.content?.toLongOrNull()
                    ?: DEFAULT_STALE_AFTER_MILLIS
            }

            // Handle backward compatibility for `androidAlarmClock`
            val androidAlarmClock = jsonObject.primitiveBoolean("androidAlarmClock") ?: true

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
                    volumeEnforced = volumeEnforced,
                    showSystemUI = true
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
                allowSameSecondScheduling = allowSameSecondScheduling,
                androidStopAlarmOnTermination = androidStopAlarmOnTermination,
                preferConnectedAudioDevice = preferConnectedAudioDevice,
                androidSnoozeDurationMillis = androidSnoozeDurationMillis,
                androidStaleAfterMillis = androidStaleAfterMillis,
                androidAlarmClock = androidAlarmClock,
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