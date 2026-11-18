package ai.getangler.analytics.device

import android.content.Context
import com.google.android.gms.ads.identifier.AdvertisingIdClient

/** [gaid] is non-null only when one is available and limit-ad-tracking is off. */
internal data class AdIdInfo(val gaid: String?, val trackingEnabled: Boolean)

internal interface AdIdProvider {
    /** Blocks; call it on the SDK executor only, never on the main thread. */
    fun fetch(): AdIdInfo
}

/** Reads the GAID with Play services' [AdvertisingIdClient]. Never throws. */
internal class PlayAdIdProvider(context: Context) : AdIdProvider {
    private val context = context.applicationContext

    override fun fetch(): AdIdInfo = try {
        val info = AdvertisingIdClient.getAdvertisingIdInfo(context)
        val id = AdIds.normalize(info.id, info.isLimitAdTrackingEnabled)
        AdIdInfo(id, id != null)
    } catch (e: Throwable) {
        // Play services missing or outdated, IO errors, or the AD_ID permission removed.
        AdIdInfo(null, false)
    }
}

internal object AdIds {
    private const val ZEROS = "00000000-0000-0000-0000-000000000000"

    /** The GAID to send, or null when limit-ad-tracking is on or the ID is empty or all zeros. */
    fun normalize(id: String?, limitAdTracking: Boolean): String? =
        if (limitAdTracking || id.isNullOrEmpty() || id == ZEROS) null else id
}
