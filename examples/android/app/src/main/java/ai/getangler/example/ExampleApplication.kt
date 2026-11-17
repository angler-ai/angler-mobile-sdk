package ai.getangler.example

import ai.getangler.analytics.Angler
import ai.getangler.analytics.AnglerConfiguration
import android.app.Application

class ExampleApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Angler.configure(
            this,
            AnglerConfiguration(
                workspaceId = BuildConfig.ANGLER_WORKSPACE_ID,
                token = BuildConfig.ANGLER_TOKEN,
                domain = "dev-data.getangler.ai",
                debugLogging = true,
            ),
        )
    }
}
