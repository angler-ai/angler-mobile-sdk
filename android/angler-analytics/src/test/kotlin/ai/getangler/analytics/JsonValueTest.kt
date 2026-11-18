package ai.getangler.analytics

import ai.getangler.analytics.payload.JsonValue
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Date

class JsonValueTest {
    @Test fun booleanStaysBoolean() = assertEquals(JsonValue.Bool(true), JsonValue.from(true))

    @Test fun intBecomesNum() = assertEquals(JsonValue.Num(3.0), JsonValue.from(3))

    @Test fun unsupportedValueDroppedInsideMap() =
        assertEquals(JsonValue.Obj(mapOf("a" to JsonValue.Num(1.0))), JsonValue.from(mapOf("a" to 1, "d" to Date())))

    @Test fun unsupportedTopLevelIsNull() = assertNull(JsonValue.from(Date()))

    @Test fun nonFiniteDropped() = assertNull(JsonValue.from(Double.NaN))

    @Test fun toJsonIsCompactWithSortedKeys() {
        val v = JsonValue.Obj(mapOf("b" to JsonValue.Num(1.0), "a" to JsonValue.Arr(listOf(JsonValue.Str("x/\"é\n"), JsonValue.Null, JsonValue.Bool(false)))))
        assertEquals("{\"a\":[\"x/\\\"é\\n\",null,false],\"b\":1}", v.toJson())
    }

    @Test fun fractionalNumbers() = assertEquals("[1.5,-2,0.001]", JsonValue.Arr(listOf(JsonValue.Num(1.5), JsonValue.Num(-2.0), JsonValue.Num(0.001))).toJson())

    @Test fun parseRoundTrip() {
        val json = """{"n": 1.5, "s": "é\"", "o": {}, "a": [true, null, -3e2]}"""
        val v = JsonValue.parse(json)
        assertEquals(
            JsonValue.Obj(mapOf("n" to JsonValue.Num(1.5), "s" to JsonValue.Str("é\""), "o" to JsonValue.Obj(emptyMap()),
                "a" to JsonValue.Arr(listOf(JsonValue.Bool(true), JsonValue.Null, JsonValue.Num(-300.0))))),
            v,
        )
        assertEquals(v, JsonValue.parse(v.toJson()))
    }

    @Test(expected = IllegalArgumentException::class) fun parseRejectsGarbage() { JsonValue.parse("not json") }
}

class JsonValueDepthTest {
    @Test fun selfReferencingMapDoesNotOverflow() {
        val m = HashMap<String, Any?>()
        m["a"] = 1
        m["self"] = m
        val v = JsonValue.from(m) as JsonValue.Obj
        assertEquals(JsonValue.Num(1.0), v.fields["a"])
    }

    @Test fun deepNestingBeyondLimitIsDropped() {
        var deep: Any = "leaf"
        repeat(100) { deep = listOf(deep) }
        var v: JsonValue? = JsonValue.from(deep)
        var depth = 0
        while (v is JsonValue.Arr && v.items.isNotEmpty()) { v = v.items[0]; depth++ }
        org.junit.Assert.assertTrue("depth $depth", depth in 1..JsonValue.MAX_DEPTH)
    }
}
