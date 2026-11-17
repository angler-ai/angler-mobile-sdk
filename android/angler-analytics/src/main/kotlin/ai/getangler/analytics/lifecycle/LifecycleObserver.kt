package ai.getangler.analytics.lifecycle

import ai.getangler.analytics.storage.Clock
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/**
 * `ProcessLifecycleOwner` ON_START / ON_STOP → callbacks with the time spent in the background.
 * Callbacks run on the main thread; the core hops onto its executor.
 */
internal class LifecycleObserver(
    private val clock: Clock,
    private val onForeground: (coldStart: Boolean, backgroundedMillis: Long?) -> Unit,
    private val onBackground: () -> Unit,
) : DefaultLifecycleObserver {
    companion object {
        const val SESSION_GAP_MILLIS = 1_800_000L

        fun isNewSession(backgroundedMillis: Long): Boolean = backgroundedMillis >= SESSION_GAP_MILLIS
    }

    @Volatile private var backgroundedAt: Long? = null

    override fun onStart(owner: LifecycleOwner) = handleStart()

    override fun onStop(owner: LifecycleOwner) = handleStop()

    /**
     * The first ON_START (cold start, or the replay when the observer is added) has no
     * background time; `AnglerCore.configure` handles the cold start itself.
     */
    fun handleStart() {
        val gap = backgroundedAt?.let { clock.nowMillis() - it }
        backgroundedAt = null
        onForeground(false, gap)
    }

    fun handleStop() {
        backgroundedAt = clock.nowMillis()
        onBackground()
    }
}
