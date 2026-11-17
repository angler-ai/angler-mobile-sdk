package ai.getangler.analytics.network

internal enum class FlushDecision { REMOVE, ISOLATE, DROP, SPLIT, PAUSE, RETRY }

/** HTTP result → what to do with the batch (design §7.2). Pure. */
internal object ResponsePolicy {
    /** [status] null means a network error or timeout. */
    fun decide(status: Int?, batchSize: Int): FlushDecision = when {
        status == null -> FlushDecision.RETRY
        status in 200..299 -> FlushDecision.REMOVE
        status == 400 -> if (batchSize > 1) FlushDecision.ISOLATE else FlushDecision.DROP
        status == 413 -> if (batchSize > 1) FlushDecision.SPLIT else FlushDecision.DROP
        status == 401 || status == 403 -> FlushDecision.PAUSE
        status == 429 || status in 500..599 -> FlushDecision.RETRY
        else -> FlushDecision.DROP
    }
}

internal object Backoff {
    /** `min(300, 2^(attempt-1)) × (0.5 + 0.5·r)` seconds, `r` in [0, 1). */
    fun delaySeconds(attempt: Int, r: Double): Double {
        val base = minOf(300.0, Math.pow(2.0, (maxOf(1, attempt) - 1).toDouble()))
        return base * (0.5 + 0.5 * r)
    }
}
