package ai.getangler.analytics

import ai.getangler.analytics.network.Flusher
import ai.getangler.analytics.payload.JsonValue
import ai.getangler.analytics.storage.EventQueue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class FlusherTest {
    @get:Rule val tmp = TemporaryFolder()
    private lateinit var queue: EventQueue
    private val transport = FakeTransport()
    private val scheduler = ManualScheduler()

    @Before fun setUp() {
        queue = EventQueue(File(tmp.root, "q.json"), 1000)
    }

    private fun flusher(r: Double = 0.5) = Flusher(queue, transport, "ANDROID", 100, scheduler) { r }

    private fun enqueue(n: Int, prefix: String = "e") {
        repeat(n) { queue.append(JsonValue.Obj(mapOf("event_id" to JsonValue.Str("$prefix$it")))) }
    }

    private fun firstId(i: Int) = transport.bodies[i]["data"]?.arr?.first()?.get("event_id")?.str

    @Test fun batchesOf100() {
        enqueue(250)
        flusher().flush()
        assertEquals(listOf(100, 100, 50), transport.batchSizes())
        assertEquals(0, queue.count)
    }

    @Test fun isolateDeliversGoodEvents() {
        enqueue(3)
        transport.responses.addAll(listOf(400, 201, 400, 201))
        flusher().flush()
        assertEquals(0, queue.count)
        assertEquals(4, transport.requestCount)
        assertEquals(listOf(3, 1, 1, 1), transport.batchSizes())
        assertEquals(listOf("e0", "e2"), listOf(firstId(1), firstId(3)))
    }

    @Test fun oneBadEventInBatchOf100() {
        enqueue(100)
        transport.responder = { body -> if (body["data"]!!.arr!!.any { it["event_id"]?.str == "e42" }) 400 else 201 }
        flusher().flush()
        assertEquals(0, queue.count)
        assertEquals(101, transport.requestCount)
    }

    @Test fun splitOn413() {
        enqueue(4)
        transport.responses.addAll(listOf(413, 201, 201))
        flusher().flush()
        assertEquals(listOf(4, 2, 2), transport.batchSizes())
        assertEquals(0, queue.count)
    }

    @Test fun retryKeepsEventsAndSchedulesBackoff() {
        enqueue(2)
        transport.responses.add(503)
        flusher(0.5).flush()
        assertEquals(2, queue.count)
        assertEquals(1, scheduler.delays.size)
        assertTrue(scheduler.delays[0] in 500..1000)
        scheduler.advance(1000)
        assertEquals(0, queue.count)
        assertEquals(2, transport.requestCount)
    }

    @Test fun backoffGrowsAndResetsAfterSuccess() {
        enqueue(1)
        transport.responses.addAll(listOf(null, null, 201))
        val f = flusher(0.0)
        f.flush()
        scheduler.advance(500)
        scheduler.advance(1000)
        assertEquals(listOf(500L, 1000L), scheduler.delays)
        assertEquals(0, queue.count)
        enqueue(1)
        transport.responses.add(500)
        f.flush()
        assertEquals(500L, scheduler.delays.last())
    }

    @Test fun pauseOn401StopsFlushing() {
        enqueue(2)
        transport.responses.add(401)
        val f = flusher()
        f.flush()
        assertTrue(f.isPaused)
        assertEquals(2, queue.count)
        f.flush()
        scheduler.advance(1_000_000)
        assertEquals(1, transport.requestCount)
    }

    @Test fun singleFlight() {
        enqueue(2)
        transport.autoRespond = false
        val f = flusher()
        f.flush()
        assertTrue(f.isFlushing)
        f.flush()
        f.flush()
        assertEquals(1, transport.requestCount)
        var done = 0
        f.flush { done++ }
        transport.pending.removeAt(0)(201)
        assertFalse(f.isFlushing)
        assertEquals(1, done)
        assertEquals(0, queue.count)
    }

    @Test fun eventsAppendedDuringFlushAreKept() {
        enqueue(2)
        transport.autoRespond = false
        val f = flusher()
        f.flush()
        enqueue(1, "late")
        transport.pending.removeAt(0)(201)
        assertEquals(2, transport.requestCount)
        assertEquals("late0", firstId(1))
        transport.pending.removeAt(0)(201)
        assertEquals(0, queue.count)
    }

    @Test fun requestBodyShape() {
        enqueue(1)
        flusher().flush()
        assertEquals(
            JsonValue.Obj(mapOf("src" to JsonValue.Str("ANDROID"), "data" to JsonValue.Arr(listOf(JsonValue.Obj(mapOf("event_id" to JsonValue.Str("e0"))))))),
            transport.bodies[0],
        )
    }

    @Test fun completionCalledWhenQueueEmpty() {
        var done = false
        flusher().flush { done = true }
        assertTrue(done)
        assertEquals(0, transport.requestCount)
    }

    @Test fun completionCalledWhenRetryScheduled() {
        enqueue(1)
        transport.responses.add(503)
        val f = flusher()
        var done = false
        f.flush { done = true }
        assertTrue(done)
        assertTrue(f.isFlushing)
        var second = false
        f.flush { second = true }
        assertTrue(second)
        assertEquals(1, transport.requestCount)
    }
}
