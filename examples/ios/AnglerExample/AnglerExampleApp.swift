import AnglerAnalytics
import AppTrackingTransparency
import SwiftUI

@main
struct AnglerExampleApp: App {
    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        Angler.configure(AnglerConfiguration(
            workspaceId: info["AnglerWorkspaceId"] as? String ?? "",
            token: info["AnglerToken"] as? String ?? "",
            domain: "dev-data.getangler.ai",
            debugLogging: true
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { Angler.handleDeepLink($0) }
        }
    }
}

struct ContentView: View {
    @State private var status = "Ready"

    var body: some View {
        NavigationView {
            List {
                Button("Track product_viewed") {
                    Angler.track("product_viewed", data: ["productVariant": ["id": "variant-1", "title": "Example"]])
                    status = "Tracked product_viewed"
                }
                Button("Track custom (level_up)") {
                    Angler.track("level_up", properties: ["level": "2"])
                    status = "Tracked level_up"
                }
                Button("Open deep link (gclid)") {
                    Angler.handleDeepLink(urlString: "anglerexample://product/1?gclid=example-gclid")
                    status = "Captured gclid"
                }
                Button("Request ATT") {
                    ATTrackingManager.requestTrackingAuthorization { s in
                        DispatchQueue.main.async { status = "ATT status: \(s.rawValue)" }
                    }
                }
                Button("Flush") {
                    Angler.flush()
                    status = "Flushing"
                }
                Section(footer: Text(status)) {}
            }
            .navigationTitle("Angler Example")
        }
    }
}
