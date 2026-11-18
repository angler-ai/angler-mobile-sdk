package ai.getangler.analytics.reactnative

import ai.getangler.analytics.Angler
import android.util.Log
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule

/** TurboModule `AnglerAnalytics`: forwards every spec method to the Kotlin core. Never throws. */
@ReactModule(name = AnglerAnalyticsModule.NAME)
class AnglerAnalyticsModule(reactContext: ReactApplicationContext) : NativeAnglerAnalyticsSpec(reactContext) {
    companion object {
        const val NAME = "AnglerAnalytics"
    }

    override fun getName(): String = NAME

    override fun configure(configJson: String) = guard {
        val config = ConfigParser.parse(configJson)
        if (config == null) {
            Log.w("Angler", "configure: invalid configuration JSON; ignored")
        } else {
            Angler.configure(reactApplicationContext.applicationContext, config)
        }
    }

    override fun track(name: String, dataJson: String?, propertiesJson: String?, eventId: String?) = guard {
        Angler.track(name, ConfigParser.parseMap(dataJson), ConfigParser.parseStringMap(propertiesJson), eventId)
    }

    override fun handleDeepLink(url: String) = guard { Angler.handleDeepLink(url) }

    override fun setUserId(userId: String?) = guard { Angler.setUserId(userId) }

    override fun setIdentifier(name: String, value: String?) = guard { Angler.setIdentifier(name, value) }

    override fun setApplicationTrackingEnabled(enabled: Boolean) = guard { Angler.setApplicationTrackingEnabled(enabled) }

    override fun setEnabled(enabled: Boolean) = guard { Angler.setEnabled(enabled) }

    override fun flush() = guard { Angler.flush() }

    override fun reset() = guard { Angler.reset() }

    private inline fun guard(block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.e("Angler", "react-native call failed: $t")
        }
    }
}
