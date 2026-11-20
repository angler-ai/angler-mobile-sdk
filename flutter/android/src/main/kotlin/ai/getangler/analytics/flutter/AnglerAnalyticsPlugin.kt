package ai.getangler.analytics.flutter

import ai.getangler.analytics.Angler
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Handles the `ai.getangler/analytics` channel by calling the Kotlin core. Replies null to every call but `getClientId`. */
class AnglerAnalyticsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ai.getangler/analytics").also { it.setMethodCallHandler(this) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
        try {
            when (call.method) {
                "configure" -> {
                    val config = ArgsParser.configuration(args)
                    val ctx = context
                    if (config != null && ctx != null) Angler.configure(ctx, config)
                    else Log.w("Angler", "configure: workspaceId and token are required; ignored")
                }
                "track" -> (args["name"] as? String)?.let { name ->
                    Angler.track(name, ArgsParser.jsonMap(args["dataJson"] as? String),
                        ArgsParser.stringMap(args["propertiesJson"] as? String), args["eventId"] as? String)
                }
                "handleDeepLink" -> (args["url"] as? String)?.let { Angler.handleDeepLink(it) }
                "setUserId" -> Angler.setUserId(args["userId"] as? String)
                "setIdentifier" -> (args["name"] as? String)?.let { Angler.setIdentifier(it, args["value"] as? String) }
                "setApplicationTrackingEnabled" -> (args["enabled"] as? Boolean)?.let { Angler.setApplicationTrackingEnabled(it) }
                "setEnabled" -> (args["enabled"] as? Boolean)?.let { Angler.setEnabled(it) }
                "flush" -> Angler.flush()
                "reset" -> Angler.reset()
                "getClientId" -> {
                    // Channel replies go on the main thread; the core answers on its own.
                    Angler.getClientId { id -> mainHandler.post { result.success(id) } }
                    return
                }
                else -> return result.notImplemented()
            }
        } catch (t: Throwable) {
            Log.e("Angler", "flutter call '${call.method}' failed: $t")
        }
        result.success(null)
    }
}
