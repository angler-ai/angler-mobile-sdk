package ai.getangler.analytics

import ai.getangler.analytics.device.AdIdInfo
import ai.getangler.analytics.device.AdIdProvider
import ai.getangler.analytics.device.InstallReferrerSource
import ai.getangler.analytics.lifecycle.LifecycleObserver
import ai.getangler.analytics.payload.DeviceProperty
import ai.getangler.analytics.payload.DeviceSnapshot
import ai.getangler.analytics.payload.JsonValue
import ai.getangler.analytics.storage.InMemoryStore
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class AnglerCoreTest {
    @get:Rule val tmp = TemporaryFolder()

    private val store = InMemoryStore()
    private val t0 = 1_763_402_645_123L
    private val clock = FakeClock(t0)
    private val transport = FakeTransport()
    private val scheduler = ManualScheduler()
    private val adIds = FakeAdIds()
    private val referrer = FakeReferrer()
    private val counter = AtomicInteger()
    private val executors = ArrayList<ExecutorService>()
    private val observers = ArrayList<LifecycleObserver>()

    @After fun tearDown() = executors.forEach { it.shutdownNow() }

    private fun makeCore(transport: FakeTransport = this.transport): AnglerCore {
        val executor = Executors.newSingleThreadExecutor().also { executors += it }
        return AnglerCore(
            store = store,
            clock = clock,
            queueDir = tmp.root,
            transportFactory = { transport },
            adIds = adIds,
            referrer = referrer,
            device = { _, ad, app ->
                DeviceSnapshot(listOf(DeviceProperty("os", "android"),
                    DeviceProperty("advertiser_tracking_enabled", if (ad) "1" else "0"),
                    DeviceProperty("application_tracking_enabled", if (app) "1" else "0")),
                    "AnglerAnalytics/test (Android 14; Pixel 8; native)")
            },
            uuid = { "uuid-${counter.incrementAndGet()}" },
            scheduler = scheduler,
            executor = executor,
            attachLifecycle = { observers += it },
        )
    }

    private fun config(lifecycle: Boolean = false, flushAt: Int = 20, clientId: String? = null) =
        AnglerConfiguration("ws", "tok", clientId = clientId, trackLifecycleEvents = lifecycle, flushAt = flushAt)

    private fun names(core: AnglerCore) = core.queuedBodies().map { it["custom_event_name"]?.str ?: it["event_name"]!!.str!! }

    private fun ids(e: JsonValue): Map<String, String> = e["identifiers"]!!.arr!!.associate { it["name"]!!.str!! to it["value"]!!.str!! }

    // lifecycle events

    @Test fun firstConfigureQueuesInstalledThenLaunched() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(lifecycle = true))
        core.waitUntilIdle()
        referrer.answer(null)
        assertEquals(listOf("app_installed", "app_launched"), names(core))
    }

    @Test fun secondConfigureOnlyLaunched() {
        transport.defaultStatus = null
        val first = makeCore()
        first.configure(config(lifecycle = true))
        first.waitUntilIdle()
        referrer.answer(null)
        first.waitUntilIdle()
        val second = makeCore()
        second.configure(config(lifecycle = true))
        assertEquals(listOf("app_installed", "app_launched", "app_launched"), names(second))
        assertEquals("referrer is only read on first install", 1, referrer.fetches)
    }

    @Test fun repeatConfigureIsNoOp() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(lifecycle = true))
        core.configure(config(lifecycle = true))
        core.waitUntilIdle()
        referrer.answer(null)
        assertEquals(listOf("app_installed", "app_launched"), names(core))
    }

    // track

    @Test fun trackBeforeConfigureDropped() {
        val core = makeCore()
        core.track("product_viewed")
        core.configure(config())
        assertEquals(emptyList<String>(), names(core))
    }

    @Test fun trackBuildsEventAtCallTime() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config())
        core.track("level_up", mapOf("productVariant" to mapOf("id" to "v1"), "foo" to 1), mapOf("a" to "1"))
        val e = core.queuedBodies().first()
        assertEquals(JsonValue.Str("custom_event"), e["event_name"])
        assertEquals(JsonValue.Str("2025-11-17T18:04:05.123Z"), e["timestamp"])
        assertEquals(
            JsonValue.Obj(mapOf("productVariant" to JsonValue.Obj(mapOf("id" to JsonValue.Str("v1"))),
                "customData" to JsonValue.Arr(listOf(JsonValue.Obj(mapOf("name" to JsonValue.Str("a"), "value" to JsonValue.Str("1"))))))),
            e["data"],
        )
        assertEquals(ids(e)["aid"], e["client_id"]?.str)
    }

    @Test fun clientIdOverride() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(clientId = "crm-42"))
        core.track("product_viewed")
        assertEquals(JsonValue.Str("crm-42"), core.queuedBodies().first()["client_id"])
    }

    @Test fun deepLinkBeforeConfigureIsAttributed() {
        transport.defaultStatus = null
        val core = makeCore()
        core.handleDeepLink("myapp://x?gclid=g1")
        core.configure(config())
        core.track("product_viewed")
        val e = core.queuedBodies().first()
        assertEquals("g1", ids(e)["gclid"])
        assertEquals(JsonValue.Str("myapp://x?gclid=g1"), e["url"])
    }

    @Test fun queuedEventUnaffectedByLaterSetUserId() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.setUserId("cust-1")
        core.track("product_viewed")
        val events = core.queuedBodies()
        assertNull(ids(events[0])["customer_id"])
        assertEquals("cust-1", ids(events[1])["customer_id"])
    }

    @Test fun reservedSetIdentifierIgnored() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config())
        core.setIdentifier("gclid", "spoof")
        core.setIdentifier("appsflyer_id", "af-1")
        core.track("product_viewed")
        val i = ids(core.queuedBodies().first())
        assertNull(i["gclid"])
        assertEquals("af-1", i["appsflyer_id"])
    }

    @Test fun gaidOnlyWhenAllowed() {
        transport.defaultStatus = null
        adIds.info = AdIdInfo("38400000-8cf0-11bd-b23e-10b96e40000d", true)
        val core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        val e = core.queuedBodies().first()
        assertEquals("38400000-8cf0-11bd-b23e-10b96e40000d", ids(e)["gaid"])
        assertTrue(e["device_properties"]!!.arr!!.contains(JsonValue.Obj(mapOf("name" to JsonValue.Str("advertiser_tracking_enabled"), "value" to JsonValue.Str("1")))))
    }

    @Test fun noGaidWhenLimited() {
        transport.defaultStatus = null
        adIds.info = AdIdInfo(null, false)
        val core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        val e = core.queuedBodies().first()
        assertNull(ids(e)["gaid"])
        assertTrue(e["device_properties"]!!.arr!!.contains(JsonValue.Obj(mapOf("name" to JsonValue.Str("advertiser_tracking_enabled"), "value" to JsonValue.Str("0")))))
    }

    @Test fun gaidFetchedOffCallerThread() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config())
        core.waitUntilIdle()
        assertTrue(adIds.threads.isNotEmpty())
        assertTrue(adIds.threads.none { it == Thread.currentThread() })
    }

    // opt-out and reset

    @Test fun setEnabledFalseClearsQueueAndDropsTracks() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.setEnabled(false)
        core.track("product_viewed")
        assertEquals(0, core.queuedBodies().size)
        core.waitUntilIdle()
        val next = makeCore()
        next.configure(config(lifecycle = true))
        next.track("product_viewed")
        assertEquals(0, next.queuedBodies().size)
        next.setEnabled(true)
        next.track("product_viewed")
        assertEquals(1, next.queuedBodies().size)
    }

    @Test fun resetRotatesAidWithoutInstallEvent() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(lifecycle = true))
        core.waitUntilIdle()
        referrer.answer(null)
        core.setUserId("cust-1")
        core.handleDeepLink("myapp://x?gclid=g1&fbclid=f1")
        core.track("product_viewed")
        val before = ids(core.queuedBodies().last())["aid"]
        core.reset()
        core.track("product_viewed")
        val e = core.queuedBodies().last()
        assertNotEquals(before, ids(e)["aid"])
        assertEquals(setOf("aid"), ids(e).keys)
        assertNull(e["fbc"])
        assertNull(e["url"])
        assertEquals(1, names(core).count { it == "app_installed" })
    }

    // delivery

    @Test fun newCoreSameDirectorySendsOldEvents() {
        val offline = FakeTransport().apply { defaultStatus = null }
        val a = makeCore(offline)
        a.configure(config())
        repeat(3) { a.track("product_viewed") }
        a.flush()
        assertEquals(3, a.queuedBodies().size)

        val b = makeCore()
        b.configure(config())
        b.flush()
        b.waitUntilIdle()
        assertEquals(3, transport.deliveredEventIds().size)
        assertEquals(0, b.queuedBodies().size)
    }

    @Test fun concurrentTracks() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(AnglerConfiguration("ws", "tok", trackLifecycleEvents = false, flushAt = 5000))
        val threads = (0 until 8).map { t -> Thread { repeat(125) { core.track("e_${t}_$it") } } }
        threads.forEach { it.start() }
        threads.forEach { it.join() }
        val events = core.queuedBodies()
        assertEquals(1000, events.size)
        assertEquals(1000, events.mapNotNull { it["event_id"]?.str }.toSet().size)
    }

    @Test fun flushAtTriggersSend() {
        val core = makeCore()
        core.configure(config(flushAt = 20))
        repeat(19) { core.track("product_viewed") }
        core.waitUntilIdle()
        assertEquals(0, transport.requestCount)
        core.track("product_viewed")
        core.waitUntilIdle()
        assertEquals(listOf(20), transport.batchSizes())
    }

    @Test fun flushIntervalTriggersSend() {
        val core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.waitUntilIdle()
        scheduler.advance(29_000)
        core.waitUntilIdle()
        assertEquals(0, transport.requestCount)
        scheduler.advance(1_000)
        core.waitUntilIdle()
        assertEquals(1, transport.requestCount)
        core.track("product_viewed")
        scheduler.advance(30_000)
        core.waitUntilIdle()
        assertEquals(2, transport.requestCount)
    }

    @Test fun onStopTriggersFlush() {
        val core = makeCore()
        core.configure(config())
        core.track("product_viewed")
        core.waitUntilIdle()
        observers.single().handleStop()
        core.waitUntilIdle()
        assertEquals(1, transport.requestCount)
        assertEquals(JsonValue.Str("ANDROID"), transport.bodies[0]["src"])
    }

    // sessions

    @Test fun foregroundAfter30MinStartsSessionAndClearsUrl() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(lifecycle = true))
        core.waitUntilIdle()
        referrer.answer(null)
        core.handleDeepLink("myapp://x?gclid=g1")
        core.waitUntilIdle()
        val obs = observers.single()
        obs.handleStart() // first ON_START after configure: not a new session
        obs.handleStop()
        clock.now += 1_799_000
        obs.handleStart()
        core.track("product_viewed")
        assertEquals(listOf("app_installed", "app_launched", "product_viewed"), names(core))
        assertEquals(JsonValue.Str("myapp://x?gclid=g1"), core.queuedBodies().last()["url"])
        val fetchesBefore = adIds.threads.size

        obs.handleStop()
        clock.now += 1_800_000
        obs.handleStart()
        core.track("product_viewed")
        assertEquals(listOf("app_installed", "app_launched", "product_viewed", "app_launched", "product_viewed"), names(core))
        assertNull(core.queuedBodies().last()["url"])
        assertEquals("g1", ids(core.queuedBodies().last())["gclid"])
        assertTrue("GAID re-read on a new session", adIds.threads.size > fetchesBefore)
    }

    // install referrer

    @Test fun installedWaitsForReferrer() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(lifecycle = true))
        core.waitUntilIdle()
        assertEquals(emptyList<String>(), names(core))
        scheduler.advance(1_000)
        referrer.answer("gclid=Cj0KCQ&utm_source=google")
        core.track("product_viewed")
        val events = core.queuedBodies()
        assertEquals(listOf("app_installed", "app_launched", "product_viewed"), names(core))
        assertEquals(JsonValue.Str("gclid=Cj0KCQ&utm_source=google"), events[0]["referrer"])
        assertEquals("Cj0KCQ", ids(events[0])["gclid"])
        assertNull(events[1]["referrer"])
        assertEquals("Cj0KCQ", ids(events[2])["gclid"])
        assertNull("the referrer never sets the session URL", events[2]["url"])
    }

    @Test fun installedNotBlockedByHangingReferrer() {
        transport.defaultStatus = null
        val core = makeCore()
        core.configure(config(lifecycle = true))
        core.waitUntilIdle()
        scheduler.advance(4_999)
        core.waitUntilIdle()
        assertEquals(emptyList<String>(), names(core))
        scheduler.advance(1)
        core.waitUntilIdle()
        assertEquals(listOf("app_installed", "app_launched"), names(core))
        assertNull(core.queuedBodies()[0]["referrer"])
        referrer.answer("gclid=late") // a late answer must not add a second install
        assertEquals(listOf("app_installed", "app_launched"), names(core))
    }
}

internal class FakeAdIds : AdIdProvider {
    @Volatile var info = AdIdInfo(null, false)
    val threads: MutableList<Thread> = java.util.Collections.synchronizedList(ArrayList())
    override fun fetch(): AdIdInfo {
        threads += Thread.currentThread()
        return info
    }
}

internal class FakeReferrer : InstallReferrerSource {
    @Volatile var fetches = 0
    private var callback: ((String?) -> Unit)? = null
    @Synchronized override fun fetch(callback: (String?) -> Unit) {
        fetches++
        this.callback = callback
    }

    /** Answers on a separate thread, like the Play client's main-thread callback. */
    fun answer(value: String?) {
        val cb = synchronized(this) { callback } ?: return
        Thread { cb(value) }.apply { start(); join() }
    }
}

internal fun AnglerCore.waitUntilIdle() = repeat(3) { executor.submit {}.get() }

internal fun AnglerCore.queuedBodies(): List<JsonValue> {
    waitUntilIdle()
    return executor.submit<List<JsonValue>> { eventQueue?.peek(Int.MAX_VALUE)?.map { it.body } ?: emptyList() }.get()
}

