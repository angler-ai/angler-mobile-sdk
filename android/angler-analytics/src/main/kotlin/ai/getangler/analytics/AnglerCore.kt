package ai.getangler.analytics

import ai.getangler.analytics.attribution.AttributionStore
import ai.getangler.analytics.attribution.ClickIdParser
import ai.getangler.analytics.device.AdIdInfo
import ai.getangler.analytics.device.AdIdProvider
import ai.getangler.analytics.device.InstallReferrerSource
import ai.getangler.analytics.lifecycle.LifecycleObserver
import ai.getangler.analytics.network.Flusher
import ai.getangler.analytics.network.HttpUrlConnectionTransport
import ai.getangler.analytics.network.Scheduler
import ai.getangler.analytics.network.Transport
import ai.getangler.analytics.payload.DeviceSnapshot
import ai.getangler.analytics.payload.IdentitySnapshot
import ai.getangler.analytics.payload.JsonValue
import ai.getangler.analytics.payload.PayloadBuilder
import ai.getangler.analytics.payload.TrackCall
import ai.getangler.analytics.storage.Clock
import ai.getangler.analytics.storage.EventQueue
import ai.getangler.analytics.storage.IdentityStore
import ai.getangler.analytics.storage.KeyValueStore
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.atomic.AtomicBoolean

/** All SDK state lives here and is only touched on [executor] (design §3). */
internal class AnglerCore(
    private val store: KeyValueStore,
    private val clock: Clock,
    private val queueDir: File,
    private val transportFactory: (AnglerConfiguration) -> Transport,
    private val adIds: AdIdProvider,
    private val referrer: InstallReferrerSource,
    private val device: (AnglerConfiguration, Boolean, Boolean) -> DeviceSnapshot,
    private val uuid: () -> String,
    private val scheduler: Scheduler,
    val executor: ExecutorService,
    private val attachLifecycle: (LifecycleObserver) -> Unit = {},
) {
    companion object {
        const val SRC = "ANDROID"
        const val BATCH_SIZE = 100
        const val REFERRER_WAIT_MILLIS = 5_000L
        private const val KEY_LAST_BACKGROUND = "last_background_ms"
        /** First-install time, kept until app_installed is queued (survives a kill mid-wait). */
        private const val KEY_INSTALL_PENDING = "install_pending_ms"
        private val onExecutor = ThreadLocal<Boolean>()
    }

    private val identity = IdentityStore(store)
    private val attribution = AttributionStore(store, clock)

    var configuration: AnglerConfiguration? = null
        private set
    var eventQueue: EventQueue? = null
        private set
    private var flusher: Flusher? = null
    private var lifecycleObserver: LifecycleObserver? = null

    /** Set once this process has seen the app in the foreground (its cold-start launch). */
    private var sawFirstForeground = false

    /** While the first install waits for the referrer, a launch queues behind app_installed. */
    private var installPending = false
    private val afterInstall = ArrayList<() -> Unit>()

    /** Cached GAID; read at configure and on each new session (design §8). */
    @Volatile private var adInfo = AdIdInfo(null, false)

    // MARK: public operations (any thread)

    fun configure(config: AnglerConfiguration) = post { doConfigure(config) }

    fun track(name: String, data: Map<String, Any?>? = null, properties: Map<String, String>? = null, eventId: String? = null) {
        // Time and event ID are read at call time (design §5 snapshot rule). The GAID is read
        // when the event is recorded: it is cached on the executor (by configure, which may
        // still be pending when track is called) and only changes at a new session.
        val now = clock.nowMillis()
        val generatedId = uuid()
        // On the caller's thread, so guard it: a map mutated concurrently must not crash the app.
        val json = try {
            data?.let { d ->
                d.entries.mapNotNull { (k, v) ->
                    JsonValue.from(v)?.let { k to it } ?: run { Log.debug { "dropping data['$k']: not representable as JSON" }; null }
                }.toMap()
            }
        } catch (t: Throwable) {
            Log.warning("track('$name'): data couldn't be read ($t); sending the event without it")
            null
        }
        val call = TrackCall(name, json, properties, eventId)
        post { record(call, now, generatedId, adInfo, null) }
    }

    fun track(event: AnglerEvent, data: AnglerData? = null, properties: Map<String, String>? = null, eventId: String? = null) {
        val json = try {
            (data?.toJsonValue() as? JsonValue.Obj)?.fields
        } catch (t: Throwable) {
            Log.warning("track('${event.name}'): data couldn't be read ($t); sending the event without it")
            null
        }
        track(event.name, json, properties, eventId)
    }

    fun handleDeepLink(url: String) = post {
        if (identity.isEnabled) attribution.capture(ClickIdParser.parseUrl(url), url)
    }

    fun setUserId(userId: String?) = post { identity.customerId = userId?.takeIf { it.isNotEmpty() } }

    fun setIdentifier(name: String, value: String?) = post {
        if (!identity.setIdentifier(name, value)) Log.warning("setIdentifier('$name') ignored: reserved or empty identifier name")
    }

    fun setApplicationTrackingEnabled(enabled: Boolean) = post { identity.applicationTrackingEnabled = enabled }

    fun setEnabled(enabled: Boolean) = post {
        identity.isEnabled = enabled
        if (!enabled) eventQueue?.removeAll()
    }

    fun flush() = post { flusher?.flush() }

    fun reset() = post {
        identity.reset()
        attribution.clear()
    }

    // MARK: on the executor

    private fun doConfigure(config: AnglerConfiguration) {
        configuration?.let { current ->
            if (current.workspaceId == config.workspaceId) {
                Log.debug { "configure: already configured; ignoring repeat call" }
            } else {
                Log.warning("configure: already configured for workspace '${current.workspaceId}'; ignoring '${config.workspaceId}'")
            }
            return
        }
        if (config.workspaceId.isEmpty() || config.token.isEmpty()) {
            Log.warning("configure: workspaceId and token are required")
            return
        }
        if (HttpUrlConnectionTransport.endpoint(config.domain, config.workspaceId) == null) {
            Log.error("configure: invalid domain '${config.domain}'; expected a host such as data.getangler.ai")
            return
        }
        Log.debugEnabled = config.debugLogging
        configuration = config

        val events = EventQueue(File(queueDir, "queue-${fileSafe(config.workspaceId)}.json"), config.maxQueueSize)
        eventQueue = events
        flusher = Flusher(events, HoppingTransport(transportFactory(config)), SRC, BATCH_SIZE, hoppingScheduler(), { Math.random() })

        adInfo = adIds.fetch()
        val isNewInstall = identity.ensureAid().second
        if (isNewInstall) store.putString(KEY_INSTALL_PENDING, clock.nowMillis().toString())
        val installAt = store.getString(KEY_INSTALL_PENDING)?.toLongOrNull()
        if (!identity.isEnabled) {
            events.removeAll()
            store.putString(KEY_INSTALL_PENDING, null)
        } else if (installAt != null) {
            // A first install (or one whose referrer wait was cut short by the process dying).
            val installedId = uuid()
            installPending = true
            awaitInstallReferrer { referrerString ->
                if (config.trackLifecycleEvents) {
                    record(TrackCall("app_installed", null, null, null), installAt, installedId, adInfo, referrerString)
                }
                store.putString(KEY_INSTALL_PENDING, null)
                installPending = false
                afterInstall.toList().also { afterInstall.clear() }.forEach { it() }
            }
        }

        // The cold-start app_launched is recorded on the first ON_START, not here: configure also
        // runs for background starts (FCM, WorkManager, receivers), and the URL that opened the
        // app is delivered (Activity.onCreate) after Application.onCreate. ProcessLifecycleOwner
        // replays ON_START to an observer added after the app has started.
        val observer = LifecycleObserver(
            onForeground = { val at = clock.nowMillis(); val id = uuid(); post { didEnterForeground(at, id) } },
            onBackground = { val at = clock.nowMillis(); post { didEnterBackground(at) } },
        )
        lifecycleObserver = observer
        attachLifecycle(observer)
        scheduleFlushTimer(config.flushIntervalSeconds * 1000)
    }

    /**
     * First install: reads the Play Install Referrer, stores its click IDs, and runs [then] with
     * the raw string, or with null after [REFERRER_WAIT_MILLIS] (design §6.4).
     */
    private fun awaitInstallReferrer(then: (String?) -> Unit) {
        val done = AtomicBoolean(false)
        val finish = { value: String? -> if (done.compareAndSet(false, true)) then(value) }
        hoppingScheduler().schedule(REFERRER_WAIT_MILLIS) {
            if (!done.get()) Log.debug { "install referrer: no answer within ${REFERRER_WAIT_MILLIS}ms" }
            finish(null)
        }
        referrer.fetch { value ->
            post {
                if (!value.isNullOrEmpty() && identity.isEnabled) {
                    // No real URL, so the session URL is left alone.
                    attribution.capture(ClickIdParser.parseQuery(value), null)
                }
                finish(value)
            }
        }
    }

    private fun record(call: TrackCall, at: Long, generatedId: String, ad: AdIdInfo, referrerString: String?) {
        val config = configuration
        val events = eventQueue
        if (config == null || events == null) {
            Log.warning("track('${call.name}') dropped: call Angler.configure first")
            return
        }
        if (!identity.isEnabled) return
        if (call.name.isEmpty()) {
            Log.warning("track: event name is empty; dropped")
            return
        }
        val event = PayloadBuilder.buildEvent(
            call = call,
            generatedEventId = generatedId,
            timestamp = PayloadBuilder.timestamp(at),
            clientIdOverride = config.clientId,
            identity = IdentitySnapshot(identity.ensureAid().first, identity.customerId, "gaid", ad.gaid, identity.customIdentifiers),
            attribution = attribution.snapshot(),
            device = device(config, ad.trackingEnabled, identity.applicationTrackingEnabled),
            referrer = referrerString,
        )
        events.append(event)
        Log.debug { "queued ${call.name} (${events.count} in queue)" }
        if (events.count >= config.flushAt) flusher?.flush()
    }

    private fun scheduleFlushTimer(intervalMillis: Long) {
        if (intervalMillis <= 0) return
        hoppingScheduler().schedule(intervalMillis) {
            if ((eventQueue?.count ?: 0) > 0) flusher?.flush()
            scheduleFlushTimer(intervalMillis)
        }
    }

    private fun didEnterBackground(at: Long) {
        // Persisted, so a later process can tell how long the app was away.
        store.putString(KEY_LAST_BACKGROUND, at.toString())
        if ((eventQueue?.count ?: 0) > 0) flusher?.flush()
    }

    /**
     * A cold start's first foreground, or a return after 30+ minutes in the background, is a new
     * session (design §6.3, §9): `app_launched`, and a session URL from before that background
     * is cleared. A start without a background in between is ignored.
     */
    private fun didEnterForeground(at: Long, launchId: String) {
        val config = configuration ?: return
        val lastBackground = store.getString(KEY_LAST_BACKGROUND)?.toLongOrNull()
        val coldStart = !sawFirstForeground
        if (!coldStart && lastBackground == null) return
        sawFirstForeground = true
        store.putString(KEY_LAST_BACKGROUND, null)

        var newSession = coldStart
        if (lastBackground != null && LifecycleObserver.isNewSession(at - lastBackground)) {
            attribution.clearSessionUrl(capturedAtOrBefore = lastBackground)
            if (!coldStart) adInfo = adIds.fetch()
            newSession = true
        }
        if (!newSession || !config.trackLifecycleEvents || !identity.isEnabled) return
        val launch = { record(TrackCall("app_launched", null, null, null), at, launchId, adInfo, null) }
        if (installPending) afterInstall += launch else launch()
    }

    // MARK: threading

    /** Runs [block] on the executor. Never lets an SDK error reach the host app. */
    private fun post(block: () -> Unit) {
        try {
            executor.execute {
                onExecutor.set(true)
                try {
                    block()
                } catch (t: Throwable) {
                    Log.error("internal error: $t")
                } finally {
                    onExecutor.set(false)
                }
            }
        } catch (t: Throwable) {
            Log.error("could not schedule work: $t")
        }
    }

    private fun runOnExecutor(block: () -> Unit) = if (onExecutor.get() == true) block() else post(block)

    /** Delivers transport callbacks on the executor (directly if already there). */
    private inner class HoppingTransport(private val base: Transport) : Transport {
        override fun send(body: String, callback: (Int?) -> Unit) = base.send(body) { status -> runOnExecutor { callback(status) } }
    }

    private fun hoppingScheduler() = object : Scheduler {
        override fun schedule(delayMillis: Long, work: () -> Unit) = scheduler.schedule(delayMillis) { post(work) }
    }

    private fun fileSafe(s: String): String = s.map { if (it.isLetterOrDigit() || it == '-' || it == '_') it else '_' }.joinToString("")
}
