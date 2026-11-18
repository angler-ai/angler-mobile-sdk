package ai.getangler.analytics.lifecycle

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner

/**
 * `ProcessLifecycleOwner` ON_START / ON_STOP → callbacks, run on the main thread. Session
 * timing lives in `AnglerCore`, which persists it.
 */
internal class LifecycleObserver(
    private val onForeground: () -> Unit,
    private val onBackground: () -> Unit,
) : DefaultLifecycleObserver {
    companion object {
        const val SESSION_GAP_MILLIS = 1_800_000L

        fun isNewSession(backgroundedMillis: Long): Boolean = backgroundedMillis >= SESSION_GAP_MILLIS
    }

    override fun onStart(owner: LifecycleOwner) = handleStart()

    override fun onStop(owner: LifecycleOwner) = handleStop()

    fun handleStart() = onForeground()

    fun handleStop() = onBackground()
}
