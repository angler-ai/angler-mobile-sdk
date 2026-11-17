package ai.getangler.analytics.flutter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ArgsParserTest {
    @Test fun parsesConfigurationWithWrapper() {
        val c = ArgsParser.configuration(mapOf("workspaceId" to "ws", "token" to "t", "flushAt" to 5, "wrapper" to "flutter"))!!
        assertEquals(5, c.flushAt)
        assertEquals("flutter", c.wrapper)
        assertEquals("data.getangler.ai", c.domain)
    }

    @Test fun parsesOptionalFields() {
        val c = ArgsParser.configuration(mapOf(
            "workspaceId" to "ws", "token" to "t", "domain" to "dev-data.getangler.ai", "clientId" to "crm-1",
            "trackLifecycleEvents" to false, "flushIntervalSeconds" to 15, "maxQueueSize" to 50L, "debugLogging" to true,
        ))!!
        assertEquals("dev-data.getangler.ai", c.domain)
        assertEquals("crm-1", c.clientId)
        assertEquals(false, c.trackLifecycleEvents)
        assertEquals(15L, c.flushIntervalSeconds)
        assertEquals(50, c.maxQueueSize)
        assertEquals(true, c.debugLogging)
        assertEquals("flutter", c.wrapper)
    }

    @Test fun missingTokenReturnsNull() = assertNull(ArgsParser.configuration(mapOf("workspaceId" to "ws")))

    @Test fun jsonMapAndStringMap() {
        assertEquals(mapOf("productVariant" to mapOf("id" to "v1", "tags" to listOf("a", 1))), ArgsParser.jsonMap("""{"productVariant":{"id":"v1","tags":["a",1]}}"""))
        assertNull(ArgsParser.jsonMap(null))
        assertNull(ArgsParser.jsonMap("nope"))
        assertEquals(mapOf("a" to "1"), ArgsParser.stringMap("""{"a":"1","b":2}"""))
    }
}
