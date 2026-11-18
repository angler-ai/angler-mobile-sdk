package ai.getangler.analytics

import ai.getangler.analytics.payload.JsonValue
import java.io.File

internal data class FixtureCase(val name: String, val input: JsonValue, val expected: JsonValue)

/** Loads the shared cross-platform cases from `<repo>/spec/fixtures/<file>.json`. */
internal object Fixtures {
    private val dir: File
        get() = File(requireNotNull(System.getProperty("anglerFixturesDir")) { "anglerFixturesDir not set" })

    fun load(file: String): List<FixtureCase> {
        val root = JsonValue.parse(File(dir, "$file.json").readText()) as JsonValue.Obj
        return (root.fields.getValue("cases") as JsonValue.Arr).items.map { c ->
            val o = (c as JsonValue.Obj).fields
            FixtureCase((o.getValue("name") as JsonValue.Str).value, o.getValue("input"), o.getValue("expected"))
        }
    }
}

internal val JsonValue.str: String? get() = (this as? JsonValue.Str)?.value
internal val JsonValue.obj: Map<String, JsonValue>? get() = (this as? JsonValue.Obj)?.fields
internal val JsonValue.arr: List<JsonValue>? get() = (this as? JsonValue.Arr)?.items
internal operator fun JsonValue.get(key: String): JsonValue? = obj?.get(key)
internal fun JsonValue.stringMap(): Map<String, String> =
    obj.orEmpty().mapNotNull { (k, v) -> v.str?.let { k to it } }.toMap()
