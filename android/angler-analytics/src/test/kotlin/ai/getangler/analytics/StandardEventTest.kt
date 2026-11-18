package ai.getangler.analytics

import ai.getangler.analytics.payload.StandardEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StandardEventTest {
    @Test fun standardEvents() {
        assertTrue(StandardEvent.isStandard("product_viewed"))
        assertTrue(StandardEvent.isStandard("app_installed"))
        assertFalse(StandardEvent.isStandard("level_up"))
        assertEquals(19, StandardEvent.names.size)
    }

    @Test fun fixturesLoad() = assertTrue(Fixtures.load("deeplinks").isNotEmpty())
}
