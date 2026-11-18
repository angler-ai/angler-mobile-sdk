package ai.getangler.analytics

import ai.getangler.analytics.storage.Clock

/** A clock tests move by hand. */
internal class FakeClock(@Volatile var now: Long) : Clock {
    override fun nowMillis(): Long = now
}

/**
 * Records request bodies. With [autoRespond], answers synchronously from [responses] (then
 * [defaultStatus]); otherwise callbacks wait in [pending] for the test.
 */
internal class FakeTransport : ai.getangler.analytics.network.Transport {
    @Volatile var autoRespond = true
    val responses = ArrayDeque<Int?>()
    @Volatile var defaultStatus: Int? = 201
    var responder: ((ai.getangler.analytics.payload.JsonValue) -> Int?)? = null
    val bodies = java.util.Collections.synchronizedList(ArrayList<ai.getangler.analytics.payload.JsonValue>())
    val pending = java.util.Collections.synchronizedList(ArrayList<(Int?) -> Unit>())

    override fun send(body: String, callback: (Int?) -> Unit) {
        val decoded = ai.getangler.analytics.payload.JsonValue.parse(body)
        val status: Int?
        synchronized(this) {
            bodies.add(decoded)
            status = responder?.invoke(decoded) ?: if (responder != null) null else if (responses.isNotEmpty()) responses.removeFirst() else defaultStatus
        }
        if (autoRespond) callback(status) else pending.add(callback)
    }

    val requestCount: Int get() = bodies.size

    fun batchSizes(): List<Int> = synchronized(bodies) { bodies.map { it["data"]?.arr?.size ?: 0 } }

    fun deliveredEventIds(): List<String> =
        synchronized(bodies) { bodies.flatMap { it["data"]?.arr.orEmpty() }.mapNotNull { it["event_id"]?.str } }
}

/** Runs scheduled work only when the test advances time. */
internal class ManualScheduler : ai.getangler.analytics.network.Scheduler {
    var now = 0L
        private set
    private val items = ArrayList<Pair<Long, () -> Unit>>()
    val delays = ArrayList<Long>()

    @Synchronized override fun schedule(delayMillis: Long, work: () -> Unit) {
        delays.add(delayMillis)
        items.add((now + delayMillis) to work)
    }

    fun advance(millis: Long) {
        val target = now + millis
        while (true) {
            val next = synchronized(this) {
                items.filter { it.first <= target }.minByOrNull { it.first }?.also { items.remove(it) }
            } ?: break
            now = next.first
            next.second()
        }
        now = target
    }
}
