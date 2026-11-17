package ai.getangler.analytics.flutter

import ai.getangler.analytics.AnglerConfiguration
import org.json.JSONArray
import org.json.JSONObject

/** Turns channel arguments into core types. Never throws. */
internal object ArgsParser {
    /** The `configure` map → configuration with `wrapper = "flutter"`. Null without workspaceId/token. */
    fun configuration(args: Map<String, Any?>): AnglerConfiguration? {
        val workspaceId = (args["workspaceId"] as? String)?.takeIf { it.isNotEmpty() } ?: return null
        val token = (args["token"] as? String)?.takeIf { it.isNotEmpty() } ?: return null
        val d = AnglerConfiguration(workspaceId, token)
        return AnglerConfiguration(
            workspaceId = workspaceId,
            token = token,
            domain = (args["domain"] as? String)?.takeIf { it.isNotEmpty() } ?: d.domain,
            clientId = (args["clientId"] as? String)?.takeIf { it.isNotEmpty() },
            trackLifecycleEvents = args["trackLifecycleEvents"] as? Boolean ?: d.trackLifecycleEvents,
            flushAt = (args["flushAt"] as? Number)?.toInt() ?: d.flushAt,
            flushIntervalSeconds = (args["flushIntervalSeconds"] as? Number)?.toLong() ?: d.flushIntervalSeconds,
            maxQueueSize = (args["maxQueueSize"] as? Number)?.toInt() ?: d.maxQueueSize,
            debugLogging = args["debugLogging"] as? Boolean ?: d.debugLogging,
        ).apply { wrapper = "flutter" }
    }

    /** A JSON object → `Map`/`List`/primitives. Null for null or invalid input. */
    fun jsonMap(json: String?): Map<String, Any?>? {
        if (json == null) return null
        return try { toMap(JSONObject(json)) } catch (e: Exception) { null }
    }

    /** A JSON object with string values; non-string values are dropped. */
    fun stringMap(json: String?): Map<String, String>? =
        jsonMap(json)?.mapNotNull { (k, v) -> (v as? String)?.let { k to it } }?.toMap()

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
