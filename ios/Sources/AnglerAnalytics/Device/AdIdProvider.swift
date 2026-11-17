import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(AdSupport)
import AdSupport
#endif

protocol AdIdProviding {
    /// The IDFA (only when ATT is authorized) and whether ATT is authorized.
    func current() -> (idfa: String?, authorized: Bool)
}

/// Reads ATT status and the IDFA. Never requests ATT authorization; the host app owns the prompt.
struct SystemAdIdProvider: AdIdProviding {
    func current() -> (idfa: String?, authorized: Bool) {
        #if canImport(AppTrackingTransparency) && canImport(AdSupport)
        let authorized = ATTrackingManager.trackingAuthorizationStatus == .authorized
        guard authorized else { return (nil, false) }
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        return (AdIdProvider.normalize(idfa: idfa, authorized: true), true)
        #else
        return (nil, false)
        #endif
    }
}

enum AdIdProvider {
    private static let zeros = "00000000-0000-0000-0000-000000000000"

    /// The IDFA to send, or nil when ATT isn't authorized or the IDFA is empty or all zeros.
    static func normalize(idfa: String?, authorized: Bool) -> String? {
        guard authorized, let idfa, !idfa.isEmpty, idfa != zeros else { return nil }
        return idfa
    }
}
