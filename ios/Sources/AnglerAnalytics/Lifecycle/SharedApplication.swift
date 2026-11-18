#if canImport(UIKit) && os(iOS)
import UIKit

extension UIApplication {
    /// `UIApplication.shared`, looked up at run time. The symbol is unavailable to app
    /// extensions, which this package must also compile for. Nil inside an extension, where
    /// there is no application object to observe or keep alive.
    static var anglerShared: UIApplication? {
        guard !Bundle.main.bundlePath.hasSuffix(".appex") else { return nil }
        let selector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: selector) else { return nil }
        return UIApplication.perform(selector)?.takeUnretainedValue() as? UIApplication
    }
}
#endif
