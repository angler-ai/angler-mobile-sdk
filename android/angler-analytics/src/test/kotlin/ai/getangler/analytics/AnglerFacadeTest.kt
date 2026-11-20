package ai.getangler.analytics

import ai.getangler.analytics.payload.DeviceSnapshot
import ai.getangler.analytics.storage.InMemoryStore
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.util.concurrent.Executors
import kotlin.coroutines.startCoroutine

@RunWith(RobolectricTestRunner::class)
class AnglerFacadeTest {
    @get:Rule val tmp = TemporaryFolder()
    private val executor = Executors.newSingleThreadExecutor()
    private var created = 0
    private val core by lazy {
        AnglerCore(InMemoryStore(), FakeClock(1_763_402_645_123L), tmp.root, { FakeTransport().apply { defaultStatus = null } },
            FakeAdIds(), FakeReferrer(), { _, _, _ -> DeviceSnapshot(emptyList(), "ua") }, { java.util.UUID.randomUUID().toString() },
            ManualScheduler(), executor)
    }

    @After fun tearDown() {
        Angler.resetForTesting()
        executor.shutdownNow()
    }

    @Test fun callsBeforeConfigureAreReplayedAndTrackIsDropped() {
        Angler.resetForTesting()
        Angler.coreFactory = { created++; core }
        Angler.handleDeepLink("myapp://x?gclid=g1")
        Angler.setUserId("cust-1")
        Angler.track("dropped_before_configure")
        val config = AnglerConfiguration("ws", "tok", trackLifecycleEvents = false)
        Angler.configure(ApplicationProvider.getApplicationContext(), config)
        Angler.configure(ApplicationProvider.getApplicationContext(), config)
        Angler.track("product_viewed")

        assertEquals(1, created)
        val events = core.queuedBodies()
        assertEquals(listOf("product_viewed"), events.map { it["event_name"]!!.str })
        val ids = events[0]["identifiers"]!!.arr!!.associate { it["name"]!!.str!! to it["value"]!!.str!! }
        assertEquals("g1", ids["gclid"])
        assertEquals("cust-1", ids["customer_id"])
        assertSame(config, core.configuration)
    }

    @Test fun getClientIdIsNullBeforeConfigureThenTheInstallId() {
        Angler.resetForTesting()
        Angler.coreFactory = { core }
        var before: String? = "unset"
        Angler.getClientId { before = it }
        org.junit.Assert.assertNull(before)
        Angler.configure(ApplicationProvider.getApplicationContext(), AnglerConfiguration("ws", "tok", trackLifecycleEvents = false))
        val result = java.util.concurrent.CompletableFuture<String?>()
        suspend { Angler.getClientId() }.startCoroutine(
            kotlin.coroutines.Continuation(kotlin.coroutines.EmptyCoroutineContext) { result.complete(it.getOrNull()) })
        val id = result.get(5, java.util.concurrent.TimeUnit.SECONDS)
        org.junit.Assert.assertNotNull(id)
        Angler.track("product_viewed")
        assertEquals(id, core.queuedBodies().last()["client_id"]!!.str)
    }
}
