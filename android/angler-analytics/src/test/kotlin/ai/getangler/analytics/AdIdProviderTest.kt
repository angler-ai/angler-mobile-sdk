package ai.getangler.analytics

import ai.getangler.analytics.device.AdIdInfo
import ai.getangler.analytics.device.AdIds
import ai.getangler.analytics.device.PlayAdIdProvider
import ai.getangler.analytics.device.PlayInstallReferrerSource
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.shadows.ShadowLooper
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
class AdIdProviderTest {
    private val gaid = "38400000-8cf0-11bd-b23e-10b96e40000d"

    @Test fun zerosDropped() = assertNull(AdIds.normalize("00000000-0000-0000-0000-000000000000", false))

    @Test fun limitAdTrackingDropsId() = assertNull(AdIds.normalize(gaid, true))

    @Test fun idKeptWhenAllowed() = assertEquals(gaid, AdIds.normalize(gaid, false))

    @Test fun nullAndEmpty() {
        assertNull(AdIds.normalize(null, false))
        assertNull(AdIds.normalize("", false))
    }

    @Test fun playProviderWithoutPlayServicesReturnsNothing() {
        // fetch() blocks, so (as in production) call it off the main thread.
        var info: AdIdInfo? = null
        val t = Thread { info = PlayAdIdProvider(ApplicationProvider.getApplicationContext()).fetch() }
        t.start()
        t.join(10_000)
        assertEquals(AdIdInfo(null, false), info)
    }

    @Test fun referrerWithoutPlayStoreCallsBackNullOnce() {
        val latch = CountDownLatch(1)
        var calls = 0
        var value: String? = "unset"
        PlayInstallReferrerSource(ApplicationProvider.getApplicationContext()).fetch {
            calls++
            value = it
            latch.countDown()
        }
        ShadowLooper.idleMainLooper()
        assertTrue(latch.await(5, TimeUnit.SECONDS))
        ShadowLooper.idleMainLooper()
        assertEquals(1, calls)
        assertNull(value)
    }
}
