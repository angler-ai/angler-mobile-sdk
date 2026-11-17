package ai.getangler.analytics.payload

/**
 * A JSON value. Events are built as [JsonValue] at `track()` time and stored in the queue
 * exactly as they will be sent.
 */
internal sealed interface JsonValue {
    /** Compact JSON with sorted object keys. */
    fun toJson(): String = StringBuilder().also { write(it) }.toString()

    fun write(out: StringBuilder)

    data class Str(val value: String) : JsonValue {
        override fun write(out: StringBuilder) = writeString(out, value)
    }

    data class Num(val value: Double) : JsonValue {
        override fun write(out: StringBuilder) {
            if (value == Math.rint(value) && Math.abs(value) < 1e15) out.append(value.toLong()) else out.append(value.toString())
        }
    }

    data class Bool(val value: Boolean) : JsonValue {
        override fun write(out: StringBuilder) {
            out.append(if (value) "true" else "false")
        }
    }

    object Null : JsonValue {
        override fun write(out: StringBuilder) {
            out.append("null")
        }

        override fun toString(): String = "Null"
    }

    data class Arr(val items: List<JsonValue>) : JsonValue {
        override fun write(out: StringBuilder) {
            out.append('[')
            items.forEachIndexed { i, v ->
                if (i > 0) out.append(',')
                v.write(out)
            }
            out.append(']')
        }
    }

    data class Obj(val fields: Map<String, JsonValue>) : JsonValue {
        override fun write(out: StringBuilder) {
            out.append('{')
            fields.keys.sorted().forEachIndexed { i, k ->
                if (i > 0) out.append(',')
                writeString(out, k)
                out.append(':')
                fields.getValue(k).write(out)
            }
            out.append('}')
        }
    }

    companion object {
        /**
         * Converts a Kotlin/Java value. Returns null for values JSON can't represent; such
         * values are dropped from inside lists and maps.
         */
        fun from(any: Any?): JsonValue? = when (any) {
            null -> Null
            is JsonValue -> any
            is String -> Str(any)
            is Boolean -> Bool(any)
            is Number -> any.toDouble().takeIf { it.isFinite() }?.let { Num(it) }
            is Map<*, *> -> Obj(
                any.entries.mapNotNull { (k, v) -> if (k is String) from(v)?.let { k to it } else null }.toMap()
            )
            is Iterable<*> -> Arr(any.mapNotNull { from(it) })
            is Array<*> -> Arr(any.mapNotNull { from(it) })
            else -> null
        }

        /** Parses JSON text. Throws [IllegalArgumentException] on invalid input. */
        fun parse(json: String): JsonValue = Parser(json).parseDocument()

        private fun writeString(out: StringBuilder, s: String) {
            out.append('"')
            for (c in s) {
                when (c) {
                    '"' -> out.append("\\\"")
                    '\\' -> out.append("\\\\")
                    '\n' -> out.append("\\n")
                    '\r' -> out.append("\\r")
                    '\t' -> out.append("\\t")
                    '\b' -> out.append("\\b")
                    '\u000C' -> out.append("\\f")
                    else -> if (c < ' ') out.append(String.format("\\u%04x", c.code)) else out.append(c)
                }
            }
            out.append('"')
        }
    }
}

private class Parser(private val s: String) {
    private var i = 0

    fun parseDocument(): JsonValue {
        val v = value()
        skipWs()
        require(i == s.length) { "trailing characters at $i" }
        return v
    }

    private fun value(): JsonValue {
        skipWs()
        require(i < s.length) { "unexpected end of input" }
        return when (val c = s[i]) {
            '{' -> obj()
            '[' -> arr()
            '"' -> JsonValue.Str(string())
            't' -> literal("true", JsonValue.Bool(true))
            'f' -> literal("false", JsonValue.Bool(false))
            'n' -> literal("null", JsonValue.Null)
            else -> if (c == '-' || c in '0'..'9') number() else throw IllegalArgumentException("unexpected '$c' at $i")
        }
    }

    private fun obj(): JsonValue {
        i++ // {
        val fields = LinkedHashMap<String, JsonValue>()
        skipWs()
        if (peek() == '}') { i++; return JsonValue.Obj(fields) }
        while (true) {
            skipWs()
            require(peek() == '"') { "expected key at $i" }
            val k = string()
            skipWs()
            require(peek() == ':') { "expected ':' at $i" }
            i++
            fields[k] = value()
            skipWs()
            when (peek()) {
                ',' -> i++
                '}' -> { i++; return JsonValue.Obj(fields) }
                else -> throw IllegalArgumentException("expected ',' or '}' at $i")
            }
        }
    }

    private fun arr(): JsonValue {
        i++ // [
        val items = ArrayList<JsonValue>()
        skipWs()
        if (peek() == ']') { i++; return JsonValue.Arr(items) }
        while (true) {
            items.add(value())
            skipWs()
            when (peek()) {
                ',' -> i++
                ']' -> { i++; return JsonValue.Arr(items) }
                else -> throw IllegalArgumentException("expected ',' or ']' at $i")
            }
        }
    }

    private fun string(): String {
        i++ // opening quote
        val sb = StringBuilder()
        while (true) {
            require(i < s.length) { "unterminated string" }
            when (val c = s[i++]) {
                '"' -> return sb.toString()
                '\\' -> {
                    require(i < s.length) { "bad escape" }
                    when (val e = s[i++]) {
                        '"' -> sb.append('"')
                        '\\' -> sb.append('\\')
                        '/' -> sb.append('/')
                        'b' -> sb.append('\b')
                        'f' -> sb.append('\u000C')
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        't' -> sb.append('\t')
                        'u' -> {
                            require(i + 4 <= s.length) { "bad unicode escape" }
                            sb.append(s.substring(i, i + 4).toInt(16).toChar())
                            i += 4
                        }
                        else -> throw IllegalArgumentException("bad escape '\\$e'")
                    }
                }
                else -> sb.append(c)
            }
        }
    }

    private fun number(): JsonValue {
        val start = i
        while (i < s.length && (s[i] in "+-.eE" || s[i] in '0'..'9')) i++
        val d = s.substring(start, i).toDoubleOrNull() ?: throw IllegalArgumentException("bad number at $start")
        return JsonValue.Num(d)
    }

    private fun literal(word: String, v: JsonValue): JsonValue {
        require(s.startsWith(word, i)) { "unexpected token at $i" }
        i += word.length
        return v
    }

    private fun peek(): Char? = if (i < s.length) s[i] else null

    private fun skipWs() {
        while (i < s.length && s[i].isWhitespace()) i++
    }
}
