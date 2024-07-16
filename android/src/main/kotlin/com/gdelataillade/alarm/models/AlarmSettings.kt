import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.util.Date

data class AlarmSettings(
    val id: Int,
    val dateTime: Date,
    val assetAudioPath: String,
    val loopAudio: Boolean,
    val vibrate: Boolean,
    val volume: Double?,
    val fadeDuration: Double,
    val notificationTitle: String,
    val notificationBody: String,
    val enableNotificationOnKill: Boolean,
    val androidFullScreenIntent: Boolean,
    val notificationActionSettings: NotificationActionSettings
) {
    companion object {
        fun fromJson(json: Map<String, Any>): AlarmSettings? {
            val gson = Gson()
            val jsonString = gson.toJson(json)
            return gson.fromJson(jsonString, AlarmSettings::class.java)
        }
    }

    fun toJson(): String {
        return Gson().toJson(this)
    }
}