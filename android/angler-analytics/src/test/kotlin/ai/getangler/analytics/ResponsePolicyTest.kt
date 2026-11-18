package ai.getangler.analytics

import ai.getangler.analytics.network.Backoff
import ai.getangler.analytics.network.ResponsePolicy
import ai.getangler.analytics.payload.JsonValue
import org.junit.Assert.assertEquals
import org.junit.Test

class ResponsePolicyTest {
    @Test fun responsePolicyFixtures() {
        val cases = Fixtures.load("response-policy")
        assertEquals(14, cases.size)
        for (c in cases) {
            val status = (c.input["status"] as? JsonValue.Num)?.value?.toInt()
            val size = (c.input["batchSize"] as JsonValue.Num).value.toInt()
            assertEquals(c.name, c.expected.str!!.uppercase(), ResponsePolicy.decide(status, size).name)
        }
    }

    @Test fun backoffFixtures() {
        val cases = Fixtures.load("backoff")
        assertEquals(7, cases.size)
        for (c in cases) {
            val attempt = (c.input["attempt"] as JsonValue.Num).value.toInt()
            val r = (c.input["r"] as JsonValue.Num).value
            assertEquals(c.name, (c.expected as JsonValue.Num).value, Backoff.delaySeconds(attempt, r), 1e-9)
        }
    }
}
