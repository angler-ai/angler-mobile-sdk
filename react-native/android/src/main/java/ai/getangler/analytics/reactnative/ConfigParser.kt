package ai.getangler.analytics.reactnative

import ai.getangler.analytics.AnglerConfiguration
import org.json.JSONArray
import org.json.JSONObject

/** Parses the JSON strings `src/index.ts` sends over the bridge. Never throws. */
internal object ConfigParser {
    /** Null on invalid JSON or a missing `workspaceId` / `token`. Sets `wrapper = "react-native"`. */
    fun parse(json: String): AnglerConfiguration? {
        val o = try { JSONObject(json) } catch (e: Exception) { return null }
        val workspaceId = o.optString("workspaceId").takeIf { o.has("workspaceId") && it.isNotEmpty() } ?: return null
        val token = o.optString("token").takeIf { o.has("token") && it.isNotEmpty() } ?: return null
        val defaults = AnglerConfiguration(workspaceId, token)
        return AnglerConfiguration(
            workspaceId = workspaceId,
            token = token,
            domain = o.stringOrNull("domain") ?: defaults.domain,
            clientId = o.stringOrNull("clientId"),
            trackLifecycleEvents = if (o.has("trackLifecycleEvents")) o.optBoolean("trackLifecycleEvents", defaults.trackLifecycleEvents) else defaults.trackLifecycleEvents,
            flushAt = if (o.has("flushAt")) o.optInt("flushAt", defaults.flushAt) else defaults.flushAt,
            // Whole seconds on Android: round a fraction up so 0.5 doesn't become 0 (no timer).
            flushIntervalSeconds = if (o.has("flushIntervalSeconds")) Math.ceil(o.optDouble("flushIntervalSeconds", defaults.flushIntervalSeconds.toDouble())).toLong() else defaults.flushIntervalSeconds,
            maxQueueSize = if (o.has("maxQueueSize")) o.optInt("maxQueueSize", defaults.maxQueueSize) else defaults.maxQueueSize,
            debugLogging = if (o.has("debugLogging")) o.optBoolean("debugLogging", defaults.debugLogging) else defaults.debugLogging,
        ).apply { wrapper = "react-native" }
    }

    /** A JSON object → `Map`/`List`/primitives (JSON null → null). Null for null or invalid input. */
    fun parseMap(json: String?): Map<String, Any?>? {
        if (json == null) return null
        return try { toMap(JSONObject(json)) } catch (e: Exception) { null }
    }

    /** A JSON object with string values; non-string values are dropped. */
    fun parseStringMap(json: String?): Map<String, String>? =
        parseMap(json)?.mapNotNull { (k, v) -> (v as? String)?.let { k to it } }?.toMap()

    private fun JSONObject.stringOrNull(key: String): String? =
        if (has(key) && !isNull(key)) optString(key).takeIf { it.isNotEmpty() } else null

    private fun toMap(o: JSONObject): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        val keys = o.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            out[k] = convert(o.opt(k))
        }
        return out
    }

    private fun convert(v: Any?): Any? = when (v) {
        null, JSONObject.NULL -> null
        is JSONObject -> toMap(v)
        is JSONArray -> (0 until v.length()).map { convert(v.opt(it)) }
        else -> v
    }
}
