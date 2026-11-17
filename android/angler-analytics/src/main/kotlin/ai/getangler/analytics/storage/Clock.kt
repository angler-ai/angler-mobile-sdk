package ai.getangler.analytics.storage

internal fun interface Clock {
    fun nowMillis(): Long
}

internal object SystemClock : Clock {
    override fun nowMillis(): Long = System.currentTimeMillis()
}
