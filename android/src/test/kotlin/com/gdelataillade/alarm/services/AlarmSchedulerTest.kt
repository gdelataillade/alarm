package com.gdelataillade.alarm.services

import com.gdelataillade.alarm.services.AlarmScheduler.ArmMode
import org.junit.Assert.assertEquals
import org.junit.Test

class AlarmSchedulerTest {
    private val s = 31
    private val m = 23

    @Test
    fun `an alarm clock is armed with setAlarmClock`() {
        assertEquals(ArmMode.ALARM_CLOCK, AlarmScheduler.armMode(34, canScheduleExact = true, alarmClock = true))
        assertEquals(ArmMode.ALARM_CLOCK, AlarmScheduler.armMode(m, canScheduleExact = true, alarmClock = true))
    }

    @Test
    fun `an opted-out alarm keeps the previous call`() {
        assertEquals(ArmMode.EXACT_WHILE_IDLE, AlarmScheduler.armMode(34, canScheduleExact = true, alarmClock = false))
        assertEquals(ArmMode.EXACT, AlarmScheduler.armMode(m - 1, canScheduleExact = true, alarmClock = false))
    }

    @Test
    fun `without the exact alarm permission both fall back to inexact`() {
        // setAlarmClock needs the same permission, so it cannot bypass the fallback.
        for (alarmClock in listOf(true, false)) {
            assertEquals(ArmMode.INEXACT_WHILE_IDLE, AlarmScheduler.armMode(s, canScheduleExact = false, alarmClock = alarmClock))
        }
    }
}
