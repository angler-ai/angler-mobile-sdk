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

    @Test fun observerForwardsStartAndStop() {
        val events = ArrayList<String>()
        val obs = LifecycleObserver(onForeground = { events += "start" }, onBackground = { events += "stop" })
        obs.handleStart()
        obs.handleStop()
        assertEquals(listOf("start", "stop"), events)
    }
}
