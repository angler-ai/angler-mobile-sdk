// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AnglerAnalytics",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "AnglerAnalytics", targets: ["AnglerAnalytics"]),
    ],
    targets: [
        .target(
            name: "AnglerAnalytics",
            path: "ios/Sources/AnglerAnalytics",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "AnglerAnalyticsTests",
            dependencies: ["AnglerAnalytics"],
            path: "ios/Tests/AnglerAnalyticsTests"
        ),
    ]
)
