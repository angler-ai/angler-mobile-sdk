package ai.getangler.analytics

import ai.getangler.analytics.attribution.AttributionSnapshot
import ai.getangler.analytics.attribution.AttributionStore
import ai.getangler.analytics.storage.InMemoryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AttributionStoreTest {
    private val t0 = 1_763_402_645_123L
    private val day = 86_400_000L

    @Test fun clickIdExpiresAfter400Days() {
        val s = InMemoryStore()
        val clock = FakeClock(t0)
        AttributionStore(s, clock).capture(mapOf("gclid" to "g1"), null)
        clock.now = t0 + 399 * day
        assertEquals(mapOf("gclid" to "g1"), AttributionStore(s, clock).snapshot().clickIds)
        clock.now = t0 + 401 * day
        assertEquals(emptyMap<String, String>(), AttributionStore(s, clock).snapshot().clickIds)
    }

    @Test fun newValueReplacesOldAndResetsExpiry() {
        val clock = FakeClock(t0)
        val a = AttributionStore(InMemoryStore(), clock)
        a.capture(mapOf("gclid" to "g1"), null)
        clock.now = t0 + 300 * day
        a.capture(mapOf("gclid" to "g2"), null)
        clock.now = t0 + 500 * day
        assertEquals(mapOf("gclid" to "g2"), a.snapshot().clickIds)
    }

    @Test fun linkFbcIsSentAsIsWithItsFbclid() {
        val clock = FakeClock(t0)
        val a = AttributionStore(InMemoryStore(), clock)
        a.capture(mapOf("fbc" to "fb.1.1700000000000.IwAR0abc", "fbp" to "fb.1.1.2"), null)
        assertEquals("fb.1.1700000000000.IwAR0abc", a.snapshot().fbc)
        assertEquals(mapOf("fbclid" to "IwAR0abc", "fbp" to "fb.1.1.2"), a.snapshot().clickIds)
        clock.now = t0 + 60_000
        a.capture(mapOf("fbclid" to "IwAR0abc"), null)
        assertEquals("fb.1.1700000000000.IwAR0abc", a.snapshot().fbc)
    }

    @Test fun linkFbcWinsOverFbclidInTheSameLink() {
        val a = AttributionStore(InMemoryStore(), FakeClock(t0))
        a.capture(mapOf("fbclid" to "other", "fbc" to "fb.1.1700000000000.IwAR0abc"), null)
        assertEquals("fb.1.1700000000000.IwAR0abc", a.snapshot().fbc)
        assertEquals(mapOf("fbclid" to "IwAR0abc"), a.snapshot().clickIds)
    }

    @Test fun malformedLinkFbcIsIgnored() {
        val a = AttributionStore(InMemoryStore(), FakeClock(t0))
        a.capture(mapOf("fbc" to "not-an-fbc", "fbclid" to "f1"), null)
        assertEquals("fb.1.1763402645123.f1", a.snapshot().fbc)
        assertEquals(mapOf("fbclid" to "f1"), a.snapshot().clickIds)
        assertNull(a.fbclidInFbc("fb.1.2."))
        assertEquals("a.b", a.fbclidInFbc("fb.1.2.a.b"))
    }

    @Test fun fbcKeptForSameFbclidReplacedForNew() {
        val clock = FakeClock(t0)
        val a = AttributionStore(InMemoryStore(), clock)
        a.capture(mapOf("fbclid" to "f1"), null)
        assertEquals("fb.1.1763402645123.f1", a.snapshot().fbc)
        clock.now = t0 + 60_000
        a.capture(mapOf("fbclid" to "f1"), null)
        assertEquals("fb.1.1763402645123.f1", a.snapshot().fbc)
        a.capture(mapOf("fbclid" to "f2"), null)
        assertEquals("fb.1.1763402705123.f2", a.snapshot().fbc)
    }

    @Test fun fbcExpiresWithFbclid() {
        val s = InMemoryStore()
        val clock = FakeClock(t0)
        AttributionStore(s, clock).capture(mapOf("fbclid" to "f1"), null)
        clock.now = t0 + 401 * day
        assertNull(AttributionStore(s, clock).snapshot().fbc)
    }

    @Test fun sessionUrlClearedButClickIdsKept() {
        val a = AttributionStore(InMemoryStore(), FakeClock(t0))
        a.capture(mapOf("gclid" to "g"), "myapp://x?gclid=g")
        assertEquals("myapp://x?gclid=g", a.snapshot().url)
        a.clearSessionUrl()
        assertNull(a.snapshot().url)
        assertEquals(mapOf("gclid" to "g"), a.snapshot().clickIds)
    }

    @Test fun captureWithNullUrlKeepsExistingUrl() {
        val a = AttributionStore(InMemoryStore(), FakeClock(t0))
        a.capture(emptyMap(), "myapp://x")
        a.capture(mapOf("gclid" to "g"), null)
        assertEquals("myapp://x", a.snapshot().url)
    }

    @Test fun clearRemovesEverything() {
        val a = AttributionStore(InMemoryStore(), FakeClock(t0))
        a.capture(mapOf("fbclid" to "f1", "gclid" to "g"), "myapp://x")
        a.clear()
        assertEquals(AttributionSnapshot(emptyMap(), null, null), a.snapshot())
    }
}
