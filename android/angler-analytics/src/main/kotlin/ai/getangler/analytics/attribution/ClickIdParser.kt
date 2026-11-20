package ai.getangler.analytics.attribution

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction

/**
 * URL or query string → identifier map (design §6.1): ad click IDs, plus the browser IDs a
 * website can pass to the app in a link (its `_fbp`, `_ga` … cookies), so app events can be tied
 * to the web visitor. Takes strings rather than `android.net.Uri` so it runs in plain JVM tests
 * and never rewrites invalid encoding.
 */
internal object ClickIdParser {
    /** Query parameter (case-sensitive, after one leading `_` is dropped) → identifier name. */
    val identifierByParameter: Map<String, String> = mapOf(
        "gclid" to "gclid",
        "gbraid" to "gbraid",
        "wbraid" to "wbraid",
        "gad_source" to "gad_source",
        "fbclid" to "fbclid",
        "ttclid" to "ttclid",
        "ScCid" to "sccid",
        "rdt_cid" to "rdt_cid",
        "epik" to "epik",
        // Browser IDs, named as the web SDKs send them.
        "fbp" to "fbp",
        "fbc" to "fbc",
        "ga" to "ga",
        "ttp" to "ttp",
        "scid" to "scid",
        "pin_unauth" to "pin_unauth",
        "rdt_uuid" to "rdt_uuid",
    )

    /** The query is the text after the first `?` and before any `#`. Any scheme works. */
    fun parseUrl(url: String): Map<String, String> {
        val q = url.indexOf('?')
        if (q < 0) return emptyMap()
        var query = url.substring(q + 1)
        val hash = query.indexOf('#')
        if (hash >= 0) query = query.substring(0, hash)
        return parseQuery(query)
    }

    /**
     * Splits on `&`, then each pair at the first `=`. Percent-decodes name and value (`+`
     * stays `+`) and drops one leading `_` from the name, so `_fbp` is `fbp`. Empty values and
     * invalid encodings are skipped; the first remaining occurrence wins.
     */
    fun parseQuery(query: String): Map<String, String> {
        val result = LinkedHashMap<String, String>()
        for (pair in query.split('&')) {
            if (pair.isEmpty()) continue
            val eq = pair.indexOf('=')
            val rawName = if (eq >= 0) pair.substring(0, eq) else pair
            val rawValue = if (eq >= 0) pair.substring(eq + 1) else ""
            val name = percentDecode(rawName) ?: continue
            val id = identifierByParameter[name.removePrefix("_")] ?: continue
            if (id in result) continue
            val value = percentDecode(rawValue) ?: continue
            if (value.isEmpty()) continue
            result[id] = value
        }
        return result
    }

    /** Strict `%XX` decoding as UTF-8; null if any escape or the resulting bytes are invalid. */
    internal fun percentDecode(s: String): String? {
        if ('%' !in s) return s
        val bytes = ByteArrayOutputStream()
        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (c == '%') {
                if (i + 2 >= s.length) return null
                val hi = Character.digit(s[i + 1], 16)
                val lo = Character.digit(s[i + 2], 16)
                if (hi < 0 || lo < 0) return null
                bytes.write(hi * 16 + lo)
                i += 3
            } else {
                // Copy the literal character (and a surrogate pair) as UTF-8.
                val end = if (Character.isHighSurrogate(c) && i + 1 < s.length) i + 2 else i + 1
                bytes.write(s.substring(i, end).toByteArray(Charsets.UTF_8))
                i = end
            }
        }
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes.toByteArray()))
                .toString()
        } catch (e: CharacterCodingException) {
            null
        }
    }
}
