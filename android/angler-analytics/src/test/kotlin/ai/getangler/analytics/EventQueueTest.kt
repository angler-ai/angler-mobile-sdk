package ai.getangler.analytics

import ai.getangler.analytics.payload.JsonValue
import ai.getangler.analytics.storage.EventQueue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class EventQueueTest {
    @get:Rule val tmp = TemporaryFolder()

    private val file: File get() = File(tmp.root, "angler_analytics/queue-ws.json")

    private fun ev(id: String): JsonValue = JsonValue.Obj(mapOf("event_id" to JsonValue.Str(id)))

    @Test fun persistsAcrossInstances() {
        val q = EventQueue(file, 10)
        listOf("e1", "e2", "e3").forEach { q.append(ev(it)) }
        val reloaded = EventQueue(file, 10)
        assertEquals(listOf(ev("e1"), ev("e2"), ev("e3")), reloaded.peek(10).map { it.body })
        assertEquals(3, reloaded.count)
    }

    @Test fun dropsOldestWhenFull() {
        val q = EventQueue(file, 3)
        listOf("e1", "e2", "e3", "e4", "e5").forEach { q.append(ev(it)) }
        assertEquals(listOf(ev("e3"), ev("e4"), ev("e5")), q.peek(10).map { it.body })
        assertEquals(listOf(ev("e3"), ev("e4"), ev("e5")), EventQueue(file, 3).peek(10).map { it.body })
    }

    @Test fun removeBySeqKeepsOthers() {
        val q = EventQueue(file, 10)
        listOf("e1", "e2", "e3").forEach { q.append(ev(it)) }
        q.remove(setOf(q.peek(10)[1].seq))
        assertEquals(listOf(ev("e1"), ev("e3")), q.peek(10).map { it.body })
        assertEquals(listOf(ev("e1"), ev("e3")), EventQueue(file, 10).peek(10).map { it.body })
    }

    @Test fun removeAll() {
        val q = EventQueue(file, 10)
        q.append(ev("e1"))
        q.removeAll()
        assertEquals(0, q.count)
        assertEquals(0, EventQueue(file, 10).count)
    }

    @Test fun corruptFileStartsEmpty() {
        file.parentFile!!.mkdirs()
        file.writeText("not json")
        val q = EventQueue(file, 10)
        assertEquals(0, q.count)
        q.append(ev("e1"))
        assertEquals(listOf(ev("e1")), EventQueue(file, 10).peek(10).map { it.body })
    }

    @Test fun seqUniqueWithDuplicateEventIds() {
        val q = EventQueue(file, 10)
        q.append(ev("same"))
        q.append(ev("same"))
        assertEquals(2, q.peek(10).map { it.seq }.toSet().size)
    }

    @Test fun seqNeverReusedAfterRemovalAndReload() {
        val q = EventQueue(file, 10)
        q.append(ev("e1"))
        val first = q.peek(1)[0].seq
        q.remove(setOf(first))
        val reloaded = EventQueue(file, 10)
        reloaded.append(ev("e2"))
        assertTrue(reloaded.peek(1)[0].seq > first)
    }

    @Test fun noTempFileLeftBehind() {
        EventQueue(file, 10).append(ev("e1"))
        assertEquals(listOf("queue-ws.json"), file.parentFile!!.list()!!.toList())
    }
}
