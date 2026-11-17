package ai.getangler.analytics.device

import ai.getangler.analytics.SdkVersion
import ai.getangler.analytics.payload.DeviceProperty
import ai.getangler.analytics.payload.DeviceSnapshot
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.telephony.TelephonyManager
import android.util.DisplayMetrics
import android.hardware.display.DisplayManager
import android.view.Display
import java.util.Locale
import java.util.TimeZone

/** Collects device properties (design §5.2, Android column) and the user agent. */
internal object DeviceContext {
    private const val GB = 1024L * 1024L * 1024L

    fun collect(context: Context, wrapper: String, adTrackingEnabled: Boolean, applicationTrackingEnabled: Boolean): DeviceSnapshot {
        val props = ArrayList<DeviceProperty>()
        fun add(name: String, value: String?) {
            if (!value.isNullOrEmpty()) props += DeviceProperty(name, value)
        }
        val app = context.applicationContext ?: context
        val tz = TimeZone.getDefault()

        add("app_package", app.packageName)
        safe {
            @Suppress("DEPRECATION")
            val info = app.packageManager.getPackageInfo(app.packageName, 0)
            add("app_version_short", info.versionName)
            @Suppress("DEPRECATION")
            add("app_version_long", (if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()).toString())
        }
        add("os", "android")
        add("os_version", Build.VERSION.RELEASE)
        add("device_model_name", Build.MODEL)
        add("device_timezone", tz.id)
        add("timezone_abbreviation", tz.getDisplayName(false, TimeZone.SHORT))
        add("locale", Locale.getDefault().toString())
        safe { add("carrier", (app.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager)?.networkOperatorName) }
        safe {
            val (w, h) = screenPixels(app)
            if (w > 0 && h > 0) {
                add("screen_width", minOf(w, h).toString())
                add("screen_height", maxOf(w, h).toString())
            }
            add("screen_density", app.resources.displayMetrics.density.toString())
        }
        add("cpu_cores", Runtime.getRuntime().availableProcessors().toString())
        safe {
            val stat = StatFs(Environment.getDataDirectory().path)
            add("ext_storage_in_gb", (stat.totalBytes / GB).toString())
            add("free_ext_storage_in_gb", (stat.availableBytes / GB).toString())
        }
        add("advertiser_tracking_enabled", if (adTrackingEnabled) "1" else "0")
        add("application_tracking_enabled", if (applicationTrackingEnabled) "1" else "0")

        val ua = userAgent(SdkVersion.CURRENT, "Android", Build.VERSION.RELEASE ?: "", Build.MODEL ?: "", wrapper)
        return DeviceSnapshot(props, ua)
    }

    fun userAgent(sdkVersion: String, os: String, osVersion: String, model: String, wrapper: String): String =
        "AnglerAnalytics/$sdkVersion ($os $osVersion; $model; $wrapper)"

    /**
     * Full display size in pixels. Uses the default display's real metrics (works with an
     * application context, unlike WindowManager on API 30+), falling back to the resources.
     */
    private fun screenPixels(context: Context): Pair<Int, Int> {
        val display = (context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager)?.getDisplay(Display.DEFAULT_DISPLAY)
        if (display != null) {
            val m = DisplayMetrics()
            @Suppress("DEPRECATION")
            display.getRealMetrics(m)
            if (m.widthPixels > 0 && m.heightPixels > 0) return m.widthPixels to m.heightPixels
        }
        return context.resources.displayMetrics.let { it.widthPixels to it.heightPixels }
    }

    private inline fun safe(block: () -> Unit) {
        try { block() } catch (e: Exception) { /* property omitted when unavailable */ }
    }
}
