package ai.getangler.analytics

/** Configuration for [Angler.configure]. */
class AnglerConfiguration @JvmOverloads constructor(
    val workspaceId: String,
    /** The workspace JWT, sent as `Authorization: Bearer <token>`. */
    val token: String,
    /** `data.getangler.ai` in production, `dev-data.getangler.ai` for testing. */
    val domain: String = "data.getangler.ai",
    /** Overrides `client_id`. Defaults to the install ID. */
    val clientId: String? = null,
    val trackLifecycleEvents: Boolean = true,
    /** Number of queued events that triggers a flush. */
    val flushAt: Int = 20,
    /** Seconds between periodic flushes. */
    val flushIntervalSeconds: Long = 30,
    /** When full, the oldest event is dropped. */
    val maxQueueSize: Int = 1000,
    val debugLogging: Boolean = false,
    /**
     * Sent as the `app_id` device property, which TikTok's app events need. Defaults to the
     * package name, the same value the AppsFlyer import sends.
     */
    val appId: String? = null,
) {
    /** `native`, or set by the React Native and Flutter wrappers. */
    var wrapper: String = "native"
}
