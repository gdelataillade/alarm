package com.gdelataillade.alarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Test

/** Which alarms swiping the app away stops (#454). Queued alarms never rang, so they are never in the map. */
class AlarmServiceTerminationTest {
    @Test
    fun `each alarm follows its own setting`() {
        assertEquals(
            listOf(1, 3),
            AlarmService.idsToStopOnTermination(mapOf(1 to true, 2 to false, 3 to true)),
        )
    }

    @Test
    fun `an alarm that opted out keeps ringing`() {
        assertEquals(emptyList<Int>(), AlarmService.idsToStopOnTermination(mapOf(7 to false)))
    }

    @Test
    fun `nothing rang`() {
        assertEquals(emptyList<Int>(), AlarmService.idsToStopOnTermination(emptyMap()))
    }
}
