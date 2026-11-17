package ai.getangler.analytics

import ai.getangler.analytics.network.HttpUrlConnectionTransport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NetworkEndpointTest {
    @Test fun endpointNormalizesDomain() {
        for (domain in listOf("dev-data.getangler.ai", "https://dev-data.getangler.ai/", " HTTPS://dev-data.getangler.ai ")) {
            assertEquals(domain, "https://dev-data.getangler.ai/v1/workspaces/ws/events",
                HttpUrlConnectionTransport.endpoint(domain, "ws")?.toString())
        }
        assertEquals("https://localhost:8443/v1/workspaces/ws/events", HttpUrlConnectionTransport.endpoint("localhost:8443", "ws")?.toString())
    }

    @Test fun invalidDomainHasNoEndpoint() {
        for (domain in listOf("", "https://", "has space.ai", "data.getangler.ai/path", "http://x.ai?q=1")) {
            assertNull(domain, HttpUrlConnectionTransport.endpoint(domain, "ws"))
        }
    }
}
