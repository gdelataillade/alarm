package com.gdelataillade.alarm.services

import com.gdelataillade.alarm.models.AlarmSettings

import android.content.Context
import io.flutter.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString

const val SHARED_PREFERENCES_NAME = "AlarmSharedPreferences"

private val Context.dataStore: DataStore<Preferences> by
preferencesDataStore(SHARED_PREFERENCES_NAME)

class AlarmStorage(context: Context) {
    companion object {
        private const val TAG = "AlarmStorage"
        private const val PREFIX = "__alarm_id__"
    }

    private val dataStore = context.dataStore

    fun saveAlarm(alarmSettings: AlarmSettings) {
        return runBlocking {
            val key = stringPreferencesKey("$PREFIX${alarmSettings.id}")
            val value = Json.encodeToString(alarmSettings)
            dataStore.edit { preferences -> preferences[key] = value }
        }
    }

    fun unsaveAlarm(id: Int) {
        return runBlocking {
            val key = stringPreferencesKey("$PREFIX$id")
            dataStore.edit { preferences -> preferences.remove(key) }
        }
    }

    fun getSavedAlarms(): List<AlarmSettings> {
        return runBlocking {
            val preferences = dataStore.data.map { prefs ->
                prefs.asMap().filterKeys { it.name.startsWith(PREFIX) }
            }.first()

            val alarms = mutableListOf<AlarmSettings>()
            preferences.forEach { (key, value) ->
                if (value is String) {
                    try {
                        val alarm = Json.decodeFromString<AlarmSettings>(value)
                        alarms.add(alarm)
                    } catch (e: Exception) {
                        Log.e(
                            TAG,
                            "Error parsing alarm settings for key ${key.name}: ${e.message}"
                        )
                    }
                } else {
                    Log.w(TAG, "Skipping non-alarm preference with key: ${key.name}")
                }
            }
            alarms
        }
    }
}
