require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  # Not "AnglerAnalytics", so an app can also use the SPM package without a module clash.
  s.name         = "AnglerAnalyticsRN"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/angler-ai/angler-mobile-sdk"
  s.license      = package["license"]
  s.authors      = "Angler AI"
  s.source       = { :git => "https://github.com/angler-ai/angler-mobile-sdk.git", :tag => s.version.to_s }
  s.ios.deployment_target = "15.1"
  s.swift_version = "5.9"

  # The Swift core is compiled from source (copied in by scripts/sync-native.mjs on prepack),
  # so there's no dependency on a CocoaPods trunk pod.
  s.source_files = "ios/*.{h,mm,swift}", "ios/vendor/AnglerAnalytics/**/*.swift"
  s.resource_bundles = {
    "AnglerAnalyticsPrivacy" => ["ios/vendor/AnglerAnalytics/Resources/PrivacyInfo.xcprivacy"]
  }

  install_modules_dependencies(s)
end
