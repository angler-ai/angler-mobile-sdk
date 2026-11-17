package ai.getangler.example

import ai.getangler.analytics.Angler
import ai.getangler.analytics.AnglerData
import ai.getangler.analytics.AnglerEvent
import ai.getangler.analytics.AnglerMoney
import ai.getangler.analytics.AnglerProductVariant
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        status = TextView(this).apply { text = "Ready" }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 96, 48, 48)
        }
        fun button(label: String, action: () -> Unit) =
            layout.addView(Button(this).apply { text = label; setOnClickListener { action(); status.text = label } })

        button("Track product_viewed") {
            Angler.track(
                AnglerEvent.ProductViewed,
                AnglerData(productVariant = AnglerProductVariant(id = "variant-1", title = "Example", price = AnglerMoney(amount = 29, currencyCode = "USD"))),
            )
        }
        button("Track custom (level_up)") { Angler.track(AnglerEvent.Custom("level_up"), properties = mapOf("level" to "2")) }
        button("Open deep link (gclid)") { Angler.handleDeepLink("anglerexample://product/1?gclid=example-gclid") }
        button("Flush") { Angler.flush() }
        button("Reset") { Angler.reset() }
        layout.addView(status)
        setContentView(layout)

        // Only a fresh launch carries a new link: a restored activity, or one relaunched from
        // Recents, still has the original intent.
        val fromHistory = intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (savedInstanceState == null && !fromHistory) handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        intent?.data?.let { Angler.handleDeepLink(it) }
    }
}
