package ai.getangler.analytics

import ai.getangler.analytics.lifecycle.LifecycleObserver
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LifecycleTest {
    @Test fun isNewSession() {
        assertFalse(LifecycleObserver.isNewSession(1_799_999))
        assertTrue(LifecycleObserver.isNewSession(1_800_000))
    }

    @Test fun observerReportsBackgroundDuration() {
        val clock = FakeClock(1_000)
        var backgrounds = 0
        val foregrounds = ArrayList<Long?>()
        val obs = LifecycleObserver(clock, onForeground = { cold, gap -> assertFalse(cold); foregrounds += gap }, onBackground = { backgrounds++ })
        obs.handleStart()
        obs.handleStop()
        clock.now += 42_000
        obs.handleStart()
        assertEquals(1, backgrounds)
        assertEquals(listOf(null, 42_000L), foregrounds)
    }
}
