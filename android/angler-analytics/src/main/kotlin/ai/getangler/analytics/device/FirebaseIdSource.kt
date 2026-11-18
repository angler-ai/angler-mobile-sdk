package ai.getangler.analytics.device

import android.content.Context
import java.util.concurrent.TimeUnit

/** Firebase Analytics' app instance ID, or null when the app doesn't use Firebase Analytics. */
internal fun interface FirebaseIdSource {
    /** May block briefly; call it on the SDK executor only, never on the main thread. */
    fun appInstanceId(): String?

    companion object {
        val NONE = FirebaseIdSource { null }
    }
}

/**
 * Reads `FirebaseAnalytics.getAppInstanceId()` when the host app includes Firebase Analytics,
 * without the SDK depending on Firebase: the classes are looked up by reflection (kept by
 * consumer-rules.pro). A found ID is cached for the process; without Firebase it gives up for
 * good after the first try. Never throws.
 */
internal class ReflectiveFirebaseIdSource(context: Context) : FirebaseIdSource {
    private val context = context.applicationContext ?: context
    @Volatile private var cached: String? = null
    @Volatile private var unavailable = false

    override fun appInstanceId(): String? {
        cached?.let { return it }
        if (unavailable) return null
        val analytics = try {
            Class.forName("com.google.firebase.analytics.FirebaseAnalytics")
        } catch (e: Throwable) {
            unavailable = true
            return null
        }
        return try {
            val instance = analytics.getMethod("getInstance", Context::class.java).invoke(null, context)
            val task = analytics.getMethod("getAppInstanceId").invoke(instance)
            val taskClass = Class.forName("com.google.android.gms.tasks.Task")
            val id = Class.forName("com.google.android.gms.tasks.Tasks")
                .getMethod("await", taskClass, Long::class.javaPrimitiveType, TimeUnit::class.java)
                .invoke(null, task, TIMEOUT_MILLIS, TimeUnit.MILLISECONDS) as? String
            id?.takeIf { it.isNotEmpty() }?.also { cached = it }
        } catch (e: Throwable) {
            // Firebase not initialised, consent denied, or a timeout: try again next session.
            null
        }
    }

    private companion object {
        const val TIMEOUT_MILLIS = 1_000L
    }
}
