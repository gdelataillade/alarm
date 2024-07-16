import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson

class AlarmStorage(context: Context) {
    companion object {
        private const val PREFS_NAME = "alarm_prefs"
        private const val PREFIX = "__alarm_id__"
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveAlarm(alarmSettings: AlarmSettings) {
        val key = "$PREFIX${alarmSettings.id}"
        val editor = prefs.edit()
        editor.putString(key, alarmSettings.toJson())
        editor.apply()
    }

    fun unsaveAlarm(id: Int) {
        val key = "$PREFIX$id"
        val editor = prefs.edit()
        editor.remove(key)
        editor.apply()
    }

    fun getSavedAlarms(): List<AlarmSettings> {
        val alarms = mutableListOf<AlarmSettings>()
        prefs.all.forEach { (key, value) ->
            if (key.startsWith(PREFIX) && value is String) {
                val alarm = AlarmSettings.fromJson(value)
                if (alarm != null) {
                    alarms.add(alarm)
                }
            }
        }
        return alarms
    }
}