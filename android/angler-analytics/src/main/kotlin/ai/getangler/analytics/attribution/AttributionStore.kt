package ai.getangler.analytics.attribution

import ai.getangler.analytics.payload.JsonValue
import ai.getangler.analytics.storage.Clock
import ai.getangler.analytics.storage.KeyValueStore

internal data class AttributionSnapshot(val clickIds: Map<String, String>, val fbc: String?, val url: String?)

/** Persists click IDs, `fbc` and the session URL (design §6.2, §6.3). Same keys and shapes as iOS. */
internal class AttributionStore(private val store: KeyValueStore, private val clock: Clock) {
    companion object {
        const val CLICK_ID_TTL_MILLIS: Long = 400L * 86_400_000L
        private const val KEY_CLICK_IDS = "click_ids"
        private const val KEY_FBC = "fbc"
        private const val KEY_SESSION_URL = "session_url"
    }

    private data class Entry(val value: String, val capturedAtMs: Long)

    private data class FbcEntry(val value: String, val fbclid: String, val capturedAtMs: Long)

    /**
     * Stores each non-empty click ID with a fresh 400-day expiry, derives `fbc` from `fbclid`,
     * and sets the session URL when [url] is non-null.
     */
    fun capture(clickIds: Map<String, String>, url: String?) {
        val now = clock.nowMillis()
        val entries = liveEntries(now).toMutableMap()
        for ((name, value) in clickIds) if (value.isNotEmpty()) entries[name] = Entry(value, now)
        writeEntries(entries)
        val fbclid = clickIds["fbclid"]
        if (!fbclid.isNullOrEmpty() && readFbc()?.fbclid != fbclid) {
            writeFbc(FbcEntry("fb.1.$now.$fbclid", fbclid, now))
        }
        if (!url.isNullOrEmpty()) store.putString(KEY_SESSION_URL, url)
    }

    fun snapshot(): AttributionSnapshot {
        val entries = liveEntries(clock.nowMillis())
        val fbc = readFbc()?.takeIf { entries["fbclid"]?.value == it.fbclid }?.value
        return AttributionSnapshot(entries.mapValues { it.value.value }, fbc, store.getString(KEY_SESSION_URL))
    }

    fun clearSessionUrl() = store.putString(KEY_SESSION_URL, null)

    fun clear() {
        store.putString(KEY_CLICK_IDS, null)
        store.putString(KEY_FBC, null)
        store.putString(KEY_SESSION_URL, null)
    }

    private fun liveEntries(now: Long): Map<String, Entry> {
        val obj = parseObj(store.getString(KEY_CLICK_IDS)) ?: return emptyMap()
        return obj.fields.mapNotNull { (name, v) ->
            val f = (v as? JsonValue.Obj)?.fields ?: return@mapNotNull null
            val value = (f["value"] as? JsonValue.Str)?.value ?: return@mapNotNull null
            val at = (f["capturedAtMs"] as? JsonValue.Num)?.value?.toLong() ?: return@mapNotNull null
            if (now - at < CLICK_ID_TTL_MILLIS) name to Entry(value, at) else null
        }.toMap()
    }

    private fun writeEntries(entries: Map<String, Entry>) {
        if (entries.isEmpty()) return store.putString(KEY_CLICK_IDS, null)
        val obj = JsonValue.Obj(entries.mapValues { (_, e) ->
            JsonValue.Obj(mapOf("value" to JsonValue.Str(e.value), "capturedAtMs" to JsonValue.Num(e.capturedAtMs.toDouble())))
        })
        store.putString(KEY_CLICK_IDS, obj.toJson())
    }

    private fun readFbc(): FbcEntry? {
        val f = parseObj(store.getString(KEY_FBC))?.fields ?: return null
        val value = (f["value"] as? JsonValue.Str)?.value ?: return null
        val fbclid = (f["fbclid"] as? JsonValue.Str)?.value ?: return null
        val at = (f["capturedAtMs"] as? JsonValue.Num)?.value?.toLong() ?: return null
        return FbcEntry(value, fbclid, at)
    }

    private fun writeFbc(e: FbcEntry) {
        store.putString(KEY_FBC, JsonValue.Obj(mapOf(
            "value" to JsonValue.Str(e.value),
            "fbclid" to JsonValue.Str(e.fbclid),
            "capturedAtMs" to JsonValue.Num(e.capturedAtMs.toDouble()),
        )).toJson())
    }

    private fun parseObj(raw: String?): JsonValue.Obj? =
        raw?.let { runCatching { JsonValue.parse(it) }.getOrNull() as? JsonValue.Obj }
}
