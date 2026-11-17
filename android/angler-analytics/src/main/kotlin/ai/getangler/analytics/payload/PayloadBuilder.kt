package ai.getangler.analytics.payload

import ai.getangler.analytics.Log
import ai.getangler.analytics.attribution.AttributionSnapshot
import ai.getangler.analytics.storage.IdentityStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

internal data class TrackCall(
    val name: String,
    val data: Map<String, JsonValue>?,
    val properties: Map<String, String>?,
    val eventId: String?,
)

internal data class IdentitySnapshot(
    val aid: String,
    val customerId: String?,
    /** `idfa` on iOS, `gaid` on Android. */
    val adIdName: String,
    val adId: String?,
    val custom: Map<String, String>,
)

internal data class DeviceProperty(val name: String, val value: String)

internal data class DeviceSnapshot(val properties: List<DeviceProperty>, val userAgent: String)

/** Turns a track call plus snapshots into one event (design §5). Pure. */
internal object PayloadBuilder {
    val allowedDataKeys: Set<String> = setOf(
        "cart", "cartLine", "checkout", "collection", "productVariant",
        "searchResult", "customer", "form", "contacts", "customData",
    )

    /** data-api's `device_properties[].name` enum. `app_id` is allowed but never collected. */
    val allowedDeviceProperties: Set<String> = setOf(
        "app_id", "app_package", "app_version_short", "app_version_long", "os", "os_version",
        "device_model_name", "device_timezone", "locale", "timezone_abbreviation", "carrier",
        "screen_width", "screen_height", "screen_density", "cpu_cores", "ext_storage_in_gb",
        "free_ext_storage_in_gb", "advertiser_tracking_enabled", "application_tracking_enabled",
    )

    fun buildEvent(
        call: TrackCall,
        generatedEventId: String,
        timestamp: String,
        clientIdOverride: String?,
        identity: IdentitySnapshot,
        attribution: AttributionSnapshot,
        device: DeviceSnapshot,
        referrer: String?,
    ): JsonValue {
        val event = LinkedHashMap<String, JsonValue>()
        event["event_id"] = JsonValue.Str(call.eventId.nonEmpty() ?: generatedEventId)
        if (StandardEvent.isStandard(call.name)) {
            event["event_name"] = JsonValue.Str(call.name)
        } else {
            event["event_name"] = JsonValue.Str("custom_event")
            event["custom_event_name"] = JsonValue.Str(call.name)
        }
        event["timestamp"] = JsonValue.Str(timestamp)
        event["client_id"] = JsonValue.Str(clientIdOverride.nonEmpty() ?: identity.aid)
        event["user_agent"] = JsonValue.Str(device.userAgent)
        attribution.url.nonEmpty()?.let { event["url"] = JsonValue.Str(it) }
        referrer.nonEmpty()?.let { event["referrer"] = JsonValue.Str(it) }
        attribution.fbc.nonEmpty()?.let { event["fbc"] = JsonValue.Str(it) }
        event["identifiers"] = JsonValue.Arr(identifiers(identity, attribution.clickIds))
        val props = device.properties.filter { it.name in allowedDeviceProperties && it.value.isNotEmpty() }
        if (props.isNotEmpty()) {
            event["device_properties"] = JsonValue.Arr(props.map { nameValue(it.name, it.value) })
        }
        event["data"] = JsonValue.Obj(data(call.data, call.properties))
        return JsonValue.Obj(event)
    }

    fun buildBody(src: String, events: List<JsonValue>): JsonValue =
        JsonValue.Obj(mapOf("src" to JsonValue.Str(src), "data" to JsonValue.Arr(events)))

    /** UTC ISO-8601 with milliseconds, e.g. `2026-11-17T18:04:05.123Z`. */
    fun timestamp(epochMillis: Long): String {
        // SimpleDateFormat isn't thread-safe; java.time needs desugaring on API 21.
        val f = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        f.timeZone = TimeZone.getTimeZone("UTC")
        return f.format(Date(epochMillis))
    }

    private fun identifiers(identity: IdentitySnapshot, clickIds: Map<String, String>): List<JsonValue> {
        val pairs = ArrayList<Pair<String, String?>>()
        pairs += "aid" to identity.aid
        pairs += "customer_id" to identity.customerId
        pairs += identity.adIdName to identity.adId
        clickIds.toSortedMap().forEach { (k, v) -> pairs += k to v }
        identity.custom.filterKeys { it !in IdentityStore.reservedNames }.toSortedMap().forEach { (k, v) -> pairs += k to v }
        return pairs.mapNotNull { (name, value) -> value.nonEmpty()?.let { nameValue(name, it) } }
    }

    private fun data(data: Map<String, JsonValue>?, properties: Map<String, String>?): Map<String, JsonValue> {
        val out = LinkedHashMap<String, JsonValue>()
        for ((key, value) in data.orEmpty()) {
            if (key in allowedDataKeys) out[key] = value else Log.debug { "dropping data key '$key': not accepted by data-api" }
        }
        val custom = ArrayList<JsonValue>()
        (out["customData"] as? JsonValue.Arr)?.items?.forEach { item ->
            val f = (item as? JsonValue.Obj)?.fields
            if (f != null && f.size == 2 && f["name"] is JsonValue.Str && f["value"] is JsonValue.Str) {
                custom += item
            } else {
                Log.debug { "dropping customData entry: must be {name: string, value: string}" }
            }
        }
        properties.orEmpty().toSortedMap().forEach { (k, v) -> custom += nameValue(k, v) }
        if (custom.isEmpty()) out.remove("customData") else out["customData"] = JsonValue.Arr(custom)
        return out
    }

    private fun nameValue(name: String, value: String): JsonValue =
        JsonValue.Obj(mapOf("name" to JsonValue.Str(name), "value" to JsonValue.Str(value)))

    private fun String?.nonEmpty(): String? = if (isNullOrEmpty()) null else this
}
