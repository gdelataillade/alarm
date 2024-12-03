package com.gdelataillade.alarm.services

import androidx.lifecycle.LiveData

class AlarmRingingLiveData : LiveData<Boolean>() {
    companion object {
        @JvmStatic
        var instance: AlarmRingingLiveData = AlarmRingingLiveData()
    }

    fun update(alarmIsRinging: Boolean) {
        postValue(alarmIsRinging)
    }
}
