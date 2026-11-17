package ai.getangler.analytics

import ai.getangler.analytics.storage.Clock

/** A clock tests move by hand. */
internal class FakeClock(@Volatile var now: Long) : Clock {
    override fun nowMillis(): Long = now
}
