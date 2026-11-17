package ai.getangler.analytics.storage

import ai.getangler.analytics.Log
import ai.getangler.analytics.payload.JsonValue
import java.io.File
import java.io.IOException

internal data class QueuedEvent(
    /** Increases steadily and is never reused, even across reloads. */
    val seq: Long,
    /** The finished event JSON, sent exactly as stored. */
    val body: JsonValue,
)

/**
 * Disk-backed FIFO of finished events (design §7.1). Not thread-safe on its own: the SDK
 * executor serializes every call. File shape: `{"nextSeq": n, "events": [{"seq", "body"}]}`.
 */
internal class EventQueue(private val file: File, maxSize: Int) {
    private val maxSize = maxOf(1, maxSize)
    private val events = ArrayList<QueuedEvent>()
    private var nextSeq = 1L

    init {
        load()
    }

    val count: Int get() = events.size

    /** Appends an event; when full, the oldest events are dropped. */
    fun append(body: JsonValue) {
        events.add(QueuedEvent(nextSeq++, body))
        if (events.size > maxSize) {
            val dropped = events.size - maxSize
            events.subList(0, dropped).clear()
            Log.debug { "queue full: dropped $dropped oldest event(s)" }
        }
        save()
    }

    fun peek(n: Int): List<QueuedEvent> = events.take(maxOf(0, n))

    fun remove(seqs: Set<Long>) {
        if (seqs.isEmpty()) return
        if (events.removeAll { it.seq in seqs }) save()
    }

    fun removeAll() {
        events.clear()
        save()
    }

    private fun load() {
        if (!file.exists()) return
        try {
            val root = (JsonValue.parse(file.readText()) as JsonValue.Obj).fields
            val list = (root.getValue("events") as JsonValue.Arr).items.map {
                val f = (it as JsonValue.Obj).fields
                QueuedEvent((f.getValue("seq") as JsonValue.Num).value.toLong(), f.getValue("body"))
            }
            events.addAll(list.takeLast(maxSize))
            val stored = (root["nextSeq"] as? JsonValue.Num)?.value?.toLong() ?: 1L
            nextSeq = maxOf(stored, (events.lastOrNull()?.seq ?: 0L) + 1)
        } catch (e: Exception) {
            Log.warning("queue file unreadable; starting empty")
            events.clear()
            file.delete()
        }
    }

    /** Atomic write: temp file, then rename. */
    private fun save() {
        try {
            file.parentFile?.mkdirs()
            val json = JsonValue.Obj(mapOf(
                "nextSeq" to JsonValue.Num(nextSeq.toDouble()),
                "events" to JsonValue.Arr(events.map {
                    JsonValue.Obj(mapOf("seq" to JsonValue.Num(it.seq.toDouble()), "body" to it.body))
                }),
            )).toJson()
            val tmp = File(file.parentFile, "${file.name}.tmp")
            tmp.writeText(json)
            if (!tmp.renameTo(file)) {
                file.delete()
                if (!tmp.renameTo(file)) throw IOException("rename failed")
            }
        } catch (e: Exception) {
            Log.error("could not write queue file: ${e.message}")
        }
    }
}
