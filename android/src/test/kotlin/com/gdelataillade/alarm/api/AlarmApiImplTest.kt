package com.gdelataillade.alarm.api

import org.junit.Assert.assertEquals
import org.junit.Test

class AlarmApiImplTest {
    private fun ids(
        ringing: List<Int> = emptyList(),
        stored: List<Int> = emptyList(),
        tracked: Set<Int> = emptySet(),
    ) = AlarmApiImpl.idsToStopAll(ringing, stored, tracked)

    @Test
    fun `a ringing alarm missing from every other source is still stopped`() {
        assertEquals(listOf(7), ids(ringing = listOf(7)))
    }

    @Test
    fun `an alarm in all three sources is stopped once`() {
        assertEquals(listOf(7), ids(ringing = listOf(7), stored = listOf(7), tracked = setOf(7)))
    }

    @Test
    fun `ringing alarms are stopped first`() {
        assertEquals(listOf(2, 1), ids(ringing = listOf(2), stored = listOf(1, 2)))
    }

    @Test
    fun `with nothing ringing the previous two sources are unchanged`() {
        assertEquals(listOf(1, 2, 3), ids(stored = listOf(1, 2), tracked = setOf(2, 3)))
    }

    @Test
    fun `nothing to stop`() {
        assertEquals(emptyList<Int>(), ids())
    }
}
