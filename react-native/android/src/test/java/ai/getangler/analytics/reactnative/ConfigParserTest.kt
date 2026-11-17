package ai.getangler.analytics.reactnative

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ConfigParserTest {
    @Test fun parsesFieldsAndKeepsDefaults() {
        val c = ConfigParser.parse("""{"workspaceId":"ws","token":"t","flushAt":5,"wrapper":"react-native"}""")!!
        assertEquals(5, c.flushAt)
        assertEquals("data.getangler.ai", c.domain)
        assertEquals("react-native", c.wrapper)
    }

    @Test fun parsesEveryOptionalField() {
        val c = ConfigParser.parse(
            """{"workspaceId":"ws","token":"t","domain":"dev-data.getangler.ai","clientId":"crm-1",
               "trackLifecycleEvents":false,"flushIntervalSeconds":15,"maxQueueSize":50,"debugLogging":true}"""
        )!!
        assertEquals("dev-data.getangler.ai", c.domain)
        assertEquals("crm-1", c.clientId)
        assertEquals(false, c.trackLifecycleEvents)
        assertEquals(15L, c.flushIntervalSeconds)
        assertEquals(50, c.maxQueueSize)
        assertEquals(true, c.debugLogging)
        assertEquals("react-native", c.wrapper)
    }

    @Test fun fractionalFlushIntervalRoundsUp() {
        assertEquals(1L, ConfigParser.parse("""{"workspaceId":"ws","token":"t","flushIntervalSeconds":0.5}""")!!.flushIntervalSeconds)
        assertEquals(3L, ConfigParser.parse("""{"workspaceId":"ws","token":"t","flushIntervalSeconds":2.5}""")!!.flushIntervalSeconds)
    }

    @Test fun missingRequiredFieldsReturnNull() = assertNull(ConfigParser.parse("{}"))

    @Test fun invalidJsonReturnsNull() = assertNull(ConfigParser.parse("nope"))

    @Test fun parseMapTurnsNestedJsonIntoMapsAndLists() {
        val m = ConfigParser.parseMap("""{"productVariant":{"id":"v1","tags":["a",1,true,null]},"n":null}""")!!
        assertEquals(mapOf("id" to "v1", "tags" to listOf("a", 1, true, null)), m["productVariant"])
        assertEquals(true, m.containsKey("n"))
        assertNull(m["n"])
        assertNull(ConfigParser.parseMap(null))
        assertNull(ConfigParser.parseMap("[1]"))
    }

    @Test fun parseStringMapKeepsOnlyStrings() {
        assertEquals(mapOf("a" to "1"), ConfigParser.parseStringMap("""{"a":"1","b":2}"""))
        assertNull(ConfigParser.parseStringMap("bad"))
    }
}
