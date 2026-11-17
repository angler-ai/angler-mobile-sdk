package ai.getangler.analytics.storage

import android.content.Context

/** String key/value persistence. Only touched on the SDK executor. */
internal interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
}

internal class SharedPreferencesStore(context: Context, name: String = "ai.getangler.analytics") : KeyValueStore {
    private val prefs = context.applicationContext.getSharedPreferences(name, Context.MODE_PRIVATE)

    override fun getString(key: String): String? = prefs.getString(key, null)

    // commit(), not apply(): we're already off the main thread and want the aid durable.
    override fun putString(key: String, value: String?) {
        val editor = prefs.edit()
        if (value == null) editor.remove(key) else editor.putString(key, value)
        editor.commit()
    }
}

internal class InMemoryStore : KeyValueStore {
    private val values = HashMap<String, String>()

    @Synchronized override fun getString(key: String): String? = values[key]

    @Synchronized override fun putString(key: String, value: String?) {
        if (value == null) values.remove(key) else values[key] = value
    }
}
