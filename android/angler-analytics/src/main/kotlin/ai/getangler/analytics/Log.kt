package ai.getangler.analytics

/**
 * SDK logging. Debug messages only print when `debugLogging` is on; warnings and errors always
 * go to logcat. Falls back to stderr where `android.util.Log` isn't available (JVM unit tests).
 */
internal object Log {
    private const val TAG = "Angler"

    @Volatile var debugEnabled: Boolean = false

    fun debug(message: () -> String) {
        if (!debugEnabled) return
        val m = message()
        try { android.util.Log.d(TAG, m) } catch (e: RuntimeException) { System.err.println("$TAG D $m") }
    }

    fun warning(message: String) {
        try { android.util.Log.w(TAG, message) } catch (e: RuntimeException) { System.err.println("$TAG W $message") }
    }

    fun error(message: String) {
        try { android.util.Log.e(TAG, message) } catch (e: RuntimeException) { System.err.println("$TAG E $message") }
    }
}
