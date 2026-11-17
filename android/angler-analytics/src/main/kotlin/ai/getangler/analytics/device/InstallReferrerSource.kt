package ai.getangler.analytics.device

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import java.util.concurrent.atomic.AtomicBoolean

internal interface InstallReferrerSource {
    /** Calls back at most once with the raw referrer string, or null if unavailable. */
    fun fetch(callback: (String?) -> Unit)
}

/** Play Install Referrer API. Null on SERVICE_UNAVAILABLE, FEATURE_NOT_SUPPORTED, DEVELOPER_ERROR or a disconnect. */
internal class PlayInstallReferrerSource(context: Context) : InstallReferrerSource {
    private val context = context.applicationContext

    override fun fetch(callback: (String?) -> Unit) {
        val answered = AtomicBoolean(false)
        fun answer(value: String?) {
            if (answered.compareAndSet(false, true)) callback(value)
        }
        val client = try {
            InstallReferrerClient.newBuilder(context).build()
        } catch (e: Throwable) {
            return answer(null)
        }
        fun close() = try { client.endConnection() } catch (e: Throwable) { }
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    val referrer = if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try { client.installReferrer.installReferrer } catch (e: Throwable) { null }
                    } else {
                        null
                    }
                    close()
                    answer(referrer?.takeIf { it.isNotEmpty() })
                }

                override fun onInstallReferrerServiceDisconnected() {
                    close()
                    answer(null)
                }
            })
        } catch (e: Throwable) {
            close()
            answer(null)
        }
    }
}
