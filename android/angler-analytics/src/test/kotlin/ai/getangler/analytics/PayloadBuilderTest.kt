package ai.getangler.analytics

import ai.getangler.analytics.attribution.AttributionSnapshot
import ai.getangler.analytics.payload.DeviceProperty
import ai.getangler.analytics.payload.DeviceSnapshot
import ai.getangler.analytics.payload.IdentitySnapshot
import ai.getangler.analytics.payload.JsonValue
import ai.getangler.analytics.payload.PayloadBuilder
import ai.getangler.analytics.payload.TrackCall
import org.junit.Assert.assertEquals
import org.junit.Test

class PayloadBuilderTest {
    @Test fun payloadFixtures() {
        val cases = Fixtures.load("payloads")
        assertEquals(11, cases.size)
        for (c in cases) {
            val i = c.input
            val call = i["call"]!!
            val identity = i["identity"]!!
            val attribution = i["attribution"]!!
            val device = i["device"]!!
            val result = PayloadBuilder.buildEvent(
                call = TrackCall(call["name"]!!.str!!, call["data"]?.obj, call["properties"]?.stringMap(), call["eventId"]?.str),
                generatedEventId = i["generatedEventId"]!!.str!!,
                timestamp = i["timestamp"]!!.str!!,
                clientIdOverride = i["clientIdOverride"]?.str,
                identity = IdentitySnapshot(identity["aid"]!!.str!!, identity["customerId"]?.str, identity["adIdName"]!!.str!!,
                    identity["adId"]?.str, identity["custom"]!!.stringMap()),
                attribution = AttributionSnapshot(attribution["clickIds"]!!.stringMap(), attribution["fbc"]?.str, attribution["url"]?.str),
                device = DeviceSnapshot(device["properties"]!!.arr!!.map { DeviceProperty(it.arr!![0].str!!, it.arr!![1].str!!) },
                    device["userAgent"]!!.str!!),
                referrer = i["referrer"]?.str,
            )
            assertEquals(c.name, c.expected, result)
        }
    }

    @Test fun timestampFormat() {
        assertEquals("2025-11-17T18:04:05.123Z", PayloadBuilder.timestamp(1763402645123L))
        assertEquals("1970-01-01T00:00:00.000Z", PayloadBuilder.timestamp(0L))
    }

    @Test fun buildBody() {
        val e = JsonValue.Obj(mapOf("event_id" to JsonValue.Str("e1")))
        assertEquals(JsonValue.Obj(mapOf("src" to JsonValue.Str("ANDROID"), "data" to JsonValue.Arr(listOf(e)))),
            PayloadBuilder.buildBody("ANDROID", listOf(e)))
    }

    @Test fun nonStringCustomDataEntriesDropped() {
        val call = TrackCall("x", mapOf("customData" to JsonValue.Arr(listOf(JsonValue.Obj(mapOf("name" to JsonValue.Str("a"), "value" to JsonValue.Num(1.0)))))), null, null)
        val event = PayloadBuilder.buildEvent(call, "e", "t", null, IdentitySnapshot("a", null, "gaid", null, emptyMap()),
            AttributionSnapshot(emptyMap(), null, null), DeviceSnapshot(emptyList(), "ua"), null)
        assertEquals(JsonValue.Obj(emptyMap()), event["data"])
    }
}
