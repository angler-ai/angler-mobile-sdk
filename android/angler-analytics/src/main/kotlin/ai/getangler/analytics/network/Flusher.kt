package ai.getangler.analytics.network

import ai.getangler.analytics.Log
import ai.getangler.analytics.payload.PayloadBuilder
import ai.getangler.analytics.storage.EventQueue
import ai.getangler.analytics.storage.QueuedEvent

/**
 * Batches queued events, sends them, and applies the response policy and backoff (design §7).
 * Every call, and every transport callback, must happen on the owner's executor; the core
 * wraps its transport so callbacks hop back onto it.
 */
internal class Flusher(
    private val queue: EventQueue,
    private val transport: Transport,
    private val src: String,
    batchSize: Int,
    private val scheduler: Scheduler,
    private val random: () -> Double,
) {
    private val batchSize = maxOf(1, batchSize)

    var isPaused = false
        private set

    /** True while a request is in flight or a retry is waiting. */
    var isFlushing = false
        private set

    private var attempt = 0
    private var waitingForRetry = false
    private val completions = ArrayList<() -> Unit>()

    /** Event groups still to send in this cycle (after isolate or split); last = next. */
    private val pendingGroups = ArrayList<List<QueuedEvent>>()

    /**
     * Starts a flush unless one is already running (single flight) or the flusher is paused.
     * [onDone] runs when the current cycle ends: the queue is drained, sending is paused, or a
     * retry has been scheduled.
     */
    fun flush(onDone: (() -> Unit)? = null) {
        onDone?.let { completions.add(it) }
        if (isPaused) return finish()
        if (isFlushing) {
            if (waitingForRetry) runCompletions()
            return
        }
        isFlushing = true
        sendNext()
    }

    private fun sendNext() {
        val group = if (pendingGroups.isNotEmpty()) pendingGroups.removeAt(pendingGroups.size - 1) else queue.peek(batchSize)
        if (group.isEmpty()) return finish()
        val body = PayloadBuilder.buildBody(src, group.map { it.body }).toJson()
        transport.send(body) { status -> handle(status, group) }
    }

    private fun handle(status: Int?, group: List<QueuedEvent>) {
        when (ResponsePolicy.decide(status, group.size)) {
            FlushDecision.REMOVE -> {
                attempt = 0
                queue.remove(group.map { it.seq }.toSet())
                Log.debug { "delivered ${group.size} event(s)" }
            }
            FlushDecision.DROP -> {
                attempt = 0
                queue.remove(group.map { it.seq }.toSet())
                Log.error("dropping ${group.size} event(s) rejected with HTTP $status")
            }
            FlushDecision.ISOLATE -> group.reversed().forEach { pendingGroups.add(listOf(it)) }
            FlushDecision.SPLIT -> {
                val mid = group.size / 2
                pendingGroups.add(group.subList(mid, group.size))
                pendingGroups.add(group.subList(0, mid))
            }
            FlushDecision.PAUSE -> {
                isPaused = true
                pendingGroups.clear()
                Log.error("HTTP $status: check the workspace token; sending paused until next launch")
                return finish()
            }
            FlushDecision.RETRY -> {
                pendingGroups.clear()
                attempt += 1
                val delayMillis = Math.round(Backoff.delaySeconds(attempt, random()) * 1000)
                Log.debug { "send failed (${status ?: "network error"}); retrying in ${delayMillis}ms" }
                waitingForRetry = true
                scheduler.schedule(delayMillis) {
                    waitingForRetry = false
                    if (isPaused) finish() else sendNext()
                }
                // The attempt is over: release callers while the retry waits. isFlushing stays
                // true so no second cycle starts meanwhile.
                return runCompletions()
            }
        }
        sendNext()
    }

    private fun finish() {
        isFlushing = false
        runCompletions()
    }

    private fun runCompletions() {
        val done = completions.toList()
        completions.clear()
        done.forEach { it() }
    }
}
