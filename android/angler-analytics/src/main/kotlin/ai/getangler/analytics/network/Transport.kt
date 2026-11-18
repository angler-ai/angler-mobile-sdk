package ai.getangler.analytics.network

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal interface Transport {
    /** Calls back with the HTTP status, or null for a network error or timeout. */
    fun send(body: String, callback: (Int?) -> Unit)
}

/**
 * POSTs on its own background thread so a slow network never blocks the SDK executor.
 * Callbacks arrive on that thread; the core hops them back onto its executor.
 */
internal class HttpUrlConnectionTransport(
    private val endpoint: URL,
    private val token: String,
    private val io: ExecutorService = Executors.newSingleThreadExecutor { r -> Thread(r, "angler-analytics-io").apply { isDaemon = true } },
) : Transport {
    companion object {
        const val TIMEOUT_MILLIS = 15_000

        private val HOST = Regex("^[A-Za-z0-9.-]+(:[0-9]{1,5})?$")

        /**
         * `https://{domain}/v1/workspaces/{workspaceId}/events`. Accepts a bare host (optionally
         * with a port) and tolerates a leading `https://` / `http://` and a trailing `/`. Null
         * for anything else, so a typo fails loudly at configure instead of losing every event.
         */
        fun endpoint(domain: String, workspaceId: String): URL? {
            var host = domain.trim()
            for (scheme in listOf("https://", "http://")) {
                if (host.startsWith(scheme, ignoreCase = true)) host = host.substring(scheme.length)
            }
            host = host.trimEnd('/')
            if (!HOST.matches(host)) return null
            return try {
                val ws = java.net.URLEncoder.encode(workspaceId, "UTF-8").replace("+", "%20")
                URL("https://$host/v1/workspaces/$ws/events")
            } catch (e: Exception) {
                null
            }
        }
    }

    override fun send(body: String, callback: (Int?) -> Unit) {
        io.execute { callback(post(body)) }
    }

    private fun post(body: String): Int? {
        var conn: HttpURLConnection? = null
        return try {
            conn = (endpoint.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = TIMEOUT_MILLIS
                readTimeout = TIMEOUT_MILLIS
                doOutput = true
                useCaches = false
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            val bytes = body.toByteArray(Charsets.UTF_8)
            conn.setFixedLengthStreamingMode(bytes.size)
            conn.outputStream.use { it.write(bytes) }
            val status = conn.responseCode
            // Drain the response so the connection can be reused.
            (if (status >= 400) conn.errorStream else conn.inputStream)?.use { it.readBytes() }
            status
        } catch (e: IOException) {
            null
        } catch (e: RuntimeException) {
            null
        } finally {
            conn?.disconnect()
        }
    }
}
