package ai.getangler.analytics

import ai.getangler.analytics.device.DeviceContext
import ai.getangler.analytics.device.PlayAdIdProvider
import ai.getangler.analytics.device.PlayInstallReferrerSource
import ai.getangler.analytics.network.ExecutorScheduler
import ai.getangler.analytics.network.HttpUrlConnectionTransport
import ai.getangler.analytics.storage.SharedPreferencesStore
import ai.getangler.analytics.storage.SystemClock
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.ProcessLifecycleOwner
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * The Angler app SDK. Every method is safe to call from any thread and never throws. Parameters
 * are nullable for Java callers: a null where a value is required is ignored with a warning.
 */
object Angler {
    private val lock = Any()
    private var core: AnglerCore? = null

    /** Calls made before [configure] (other than [track]) are kept and replayed in order. */
    private val pending = ArrayList<(AnglerCore) -> Unit>()

    /** Builds the production core. Replaced in tests. */
    internal var coreFactory: (Context) -> AnglerCore = ::createCore

    /** Starts the SDK. Call once at launch, e.g. in `Application.onCreate`; repeat calls with the same workspace do nothing. */
    @JvmStatic
    fun configure(context: Context?, configuration: AnglerConfiguration?) {
        if (context == null || configuration == null) {
            Log.warning("configure: context and configuration are required; ignored")
            return
        }
        val replay: List<(AnglerCore) -> Unit>
        val c = synchronized(lock) {
            val existing = core
            val created = existing ?: try {
                coreFactory(context.applicationContext ?: context)
            } catch (t: Throwable) {
                Log.error("configure failed: $t")
                return
            }
            core = created
            replay = if (existing == null) pending.toList().also { pending.clear() } else emptyList()
            created
        }
        replay.forEach { it(c) }
        c.configure(configuration)
    }

    /**
     * Queues an event. Names data-api knows are sent as-is; others become `custom_event`.
     * Dropped (with a warning) before [configure].
     */
    @JvmStatic
    @JvmOverloads
    fun track(name: String?, data: Map<String, Any?>? = null, properties: Map<String, String>? = null, eventId: String? = null) {
        if (name == null) {
            Log.warning("track: event name is null; dropped")
            return
        }
        val c = synchronized(lock) { core }
        if (c == null) {
            Log.warning("track('$name') dropped: call Angler.configure first")
            return
        }
        c.track(name, data, properties, eventId)
    }

    /** Captures click IDs and the session URL. Works before [configure]. */
    @JvmStatic
    fun handleDeepLink(uri: Uri?) = handleDeepLink(uri?.toString())

    /** Like [handleDeepLink], for URL strings. */
    @JvmStatic
    fun handleDeepLink(url: String?) {
        if (url == null) return
        withCore { it.handleDeepLink(url) }
    }

    /** Sets the `customer_id` identifier; null clears it. */
    @JvmStatic
    fun setUserId(userId: String?) = withCore { it.setUserId(userId) }

    /** Sets a custom identifier such as `appsflyer_id`; null removes it. Reserved names are ignored. */
    @JvmStatic
    fun setIdentifier(name: String?, value: String?) {
        if (name == null) return Log.warning("setIdentifier: name is null; ignored")
        withCore { it.setIdentifier(name, value) }
    }

    /** Sent as `application_tracking_enabled` (default true). */
    @JvmStatic
    fun setApplicationTrackingEnabled(enabled: Boolean) = withCore { it.setApplicationTrackingEnabled(enabled) }

    /** `false` stops all collection and deletes queued events. Stored across launches. */
    @JvmStatic
    fun setEnabled(enabled: Boolean) = withCore { it.setEnabled(enabled) }

    /** Sends queued events now. */
    @JvmStatic
    fun flush() = withCore { it.flush() }

    /** Clears the user ID, custom identifiers and attribution, and creates a new install ID. */
    @JvmStatic
    fun reset() = withCore { it.reset() }

    private fun withCore(op: (AnglerCore) -> Unit) {
        val c = synchronized(lock) {
            core ?: run {
                pending.add(op)
                null
            }
        } ?: return
        op(c)
    }

    /** Test hook: forget the core and any pending calls. */
    internal fun resetForTesting() = synchronized(lock) {
        core = null
        pending.clear()
        coreFactory = ::createCore
    }

    private fun createCore(context: Context): AnglerCore {
        val executor = Executors.newSingleThreadScheduledExecutor { r -> Thread(r, "angler-analytics").apply { isDaemon = true } }
        return AnglerCore(
            store = SharedPreferencesStore(context),
            clock = SystemClock,
            queueDir = File(context.noBackupFilesDir, "angler_analytics"),
            transportFactory = { c ->
                // AnglerCore.configure only gets this far once the endpoint has been validated.
                HttpUrlConnectionTransport(requireNotNull(HttpUrlConnectionTransport.endpoint(c.domain, c.workspaceId)), c.token)
            },
            adIds = PlayAdIdProvider(context),
            referrer = PlayInstallReferrerSource(context),
            device = { c, ad, app -> DeviceContext.collect(context, c.wrapper, ad, app) },
            uuid = { UUID.randomUUID().toString().lowercase() },
            scheduler = ExecutorScheduler(executor),
            executor = executor,
            attachLifecycle = { observer ->
                Handler(Looper.getMainLooper()).post {
                    try {
                        ProcessLifecycleOwner.get().lifecycle.addObserver(observer)
                    } catch (t: Throwable) {
                        Log.error("could not observe the app lifecycle: $t")
                    }
                }
            },
        )
    }
}
