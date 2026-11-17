package ai.getangler.analytics.storage

import ai.getangler.analytics.attribution.ClickIdParser
import ai.getangler.analytics.payload.JsonValue
import java.util.UUID

/** The install ID (`aid`), the user ID, custom identifiers and the stored flags. */
internal class IdentityStore(private val store: KeyValueStore) {
    private object Key {
        const val AID = "aid"
        const val CUSTOMER_ID = "customer_id"
        const val CUSTOM = "custom_identifiers"
        const val ENABLED = "enabled"
        const val APP_TRACKING = "application_tracking_enabled"
    }

    companion object {
        /** Names a custom identifier may never use. */
        val reservedNames: Set<String> = setOf("aid", "customer_id", "idfa", "gaid") + ClickIdParser.identifierByParameter.values

        private fun newAid(): String = UUID.randomUUID().toString().lowercase()
    }

    /** Returns the stored `aid` (creating one if none exists) and whether it is new (a first launch). */
    fun ensureAid(): Pair<String, Boolean> {
        val existing = store.getString(Key.AID)
        if (!existing.isNullOrEmpty()) return existing to false
        val aid = newAid()
        store.putString(Key.AID, aid)
        return aid to true
    }

    var customerId: String?
        get() = store.getString(Key.CUSTOMER_ID)
        set(value) = store.putString(Key.CUSTOMER_ID, value)

    /** Sets or (with null) removes a custom identifier. Returns false for a reserved or empty name. */
    fun setIdentifier(name: String, value: String?): Boolean {
        if (name.isEmpty() || name in reservedNames) return false
        val ids = customIdentifiers.toMutableMap()
        if (value == null) ids.remove(name) else ids[name] = value
        store.putString(Key.CUSTOM, if (ids.isEmpty()) null else JsonValue.Obj(ids.mapValues { JsonValue.Str(it.value) }).toJson())
        return true
    }

    val customIdentifiers: Map<String, String>
        get() {
            val raw = store.getString(Key.CUSTOM) ?: return emptyMap()
            val obj = runCatching { JsonValue.parse(raw) }.getOrNull() as? JsonValue.Obj ?: return emptyMap()
            return obj.fields.mapNotNull { (k, v) -> (v as? JsonValue.Str)?.let { k to it.value } }.toMap()
        }

    var isEnabled: Boolean
        get() = store.getString(Key.ENABLED) != "0"
        set(value) = store.putString(Key.ENABLED, if (value) "1" else "0")

    var applicationTrackingEnabled: Boolean
        get() = store.getString(Key.APP_TRACKING) != "0"
        set(value) = store.putString(Key.APP_TRACKING, if (value) "1" else "0")

    /**
     * Clears the user ID and custom identifiers and rotates the `aid`. Before the first `aid`
     * exists there is nothing to rotate, so a later first launch is still an install.
     */
    fun reset() {
        store.putString(Key.CUSTOMER_ID, null)
        store.putString(Key.CUSTOM, null)
        if (store.getString(Key.AID) != null) store.putString(Key.AID, newAid())
    }
}
