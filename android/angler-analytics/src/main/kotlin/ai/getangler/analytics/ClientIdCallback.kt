package ai.getangler.analytics

/** Receives the result of [Angler.getClientId]. */
fun interface ClientIdCallback {
    fun onClientId(clientId: String?)
}
