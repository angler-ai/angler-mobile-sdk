package ai.getangler.analytics

import ai.getangler.analytics.device.DeviceContext
import ai.getangler.analytics.payload.PayloadBuilder
import androidx.test.core.app.ApplicationProvider
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class DeviceContextTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun props(ad: Boolean = false, app: Boolean = true, wrapper: String = "native") =
        DeviceContext.collect(context, wrapper, ad, app).properties.associate { it.name to it.value }

    @Test fun userAgent() = assertEquals(
        "AnglerAnalytics/1.0.0 (Android 14; Pixel 8; native)",
        DeviceContext.userAgent("1.0.0", "Android", "14", "Pixel 8", "native"),
    )

    @Test fun onlyAllowedNames() {
        val snapshot = DeviceContext.collect(context, "native", false, true)
        val names = snapshot.properties.map { it.name }
        assertEquals(names.toSet().size, names.size)
        names.forEach { assertTrue(it, it in PayloadBuilder.allowedDeviceProperties) }
        assertTrue(snapshot.properties.all { it.value.isNotEmpty() })
    }

    @Test fun appIdDefaultsToPackageNameLikeAppsFlyer() {
        assertEquals(context.packageName, props()["app_id"])
        val custom = DeviceContext.collect(context, "native", false, true, " com.shop.app ")
        assertEquals("com.shop.app", custom.properties.first { it.name == "app_id" }.value)
    }

    @Test fun osPackageAndFlags() {
        val p = props(ad = false, app = false)
        assertEquals("android", p["os"])
        assertEquals(context.packageName, p["app_package"])
        assertEquals("0", p["advertiser_tracking_enabled"])
        assertEquals("0", p["application_tracking_enabled"])
        assertEquals("1", props(ad = true, app = true)["advertiser_tracking_enabled"])
    }

    @Test fun screenIsPortraitPixels() {
        val p = props()
        val w = p.getValue("screen_width").toInt()
        val h = p.getValue("screen_height").toInt()
        assertTrue(w > 0)
        assertTrue(w <= h)
        assertTrue(p.getValue("screen_density").toFloat() > 0f)
    }

    @Test fun storageInWholeGb() {
        val p = props()
        p["ext_storage_in_gb"]?.let { assertTrue(it.toLong() >= 0) }
        p["free_ext_storage_in_gb"]?.let { assertTrue(it.toLong() >= 0) }
        assertTrue(p.getValue("cpu_cores").toInt() > 0)
    }

    @Test fun userAgentCarriesWrapper() {
        val ua = DeviceContext.collect(context, "flutter", false, true).userAgent
        assertTrue(ua, ua.startsWith("AnglerAnalytics/${SdkVersion.CURRENT} (Android "))
        assertTrue(ua, ua.endsWith("; flutter)"))
    }
}
