version = File.read(File.join(__dir__, '..', 'pubspec.yaml'))[/^version:\s*(\S+)/, 1]

Pod::Spec.new do |s|
  s.name             = 'angler_analytics'
  s.version          = version
  s.summary          = 'Angler app analytics and attribution for Flutter.'
  s.homepage         = 'https://getangler.ai'
  s.license          = { :type => 'MIT' }
  s.author           = 'Angler AI'
  s.source           = { :path => '.' }
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'
  s.dependency 'Flutter'

  # The Swift core is compiled from source (copied in by scripts/sync_native.sh).
  s.source_files = 'Classes/**/*.swift'
  s.resource_bundles = {
    'AnglerAnalyticsPrivacy' => ['Classes/vendor/AnglerAnalytics/Resources/PrivacyInfo.xcprivacy']
  }
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
