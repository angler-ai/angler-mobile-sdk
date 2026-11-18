package ai.getangler.analytics

import ai.getangler.analytics.attribution.ClickIdParser
import org.junit.Assert.assertEquals
import org.junit.Test

class ClickIdParserTest {
    @Test fun deeplinkFixtures() {
        val cases = Fixtures.load("deeplinks")
        assertEquals(12, cases.size)
        for (c in cases) assertEquals(c.name, c.expected.stringMap(), ClickIdParser.parseUrl(c.input.str!!))
    }

    @Test fun installReferrerFixtures() {
        val cases = Fixtures.load("install-referrer")
        assertEquals(4, cases.size)
        for (c in cases) assertEquals(c.name, c.expected.stringMap(), ClickIdParser.parseQuery(c.input.str!!))
    }

    @Test fun skippedPairDoesNotBlockLaterOccurrence() =
        assertEquals(mapOf("gclid" to "x"), ClickIdParser.parseQuery("gclid=&gclid=x"))

    @Test fun nonAsciiValueDecoded() =
        assertEquals(mapOf("epik" to "é"), ClickIdParser.parseQuery("epik=%C3%A9"))
}
