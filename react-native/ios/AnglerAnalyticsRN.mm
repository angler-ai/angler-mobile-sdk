#import <AnglerAnalyticsSpec/AnglerAnalyticsSpec.h>
#import <React/RCTBridgeModule.h>

#if __has_include(<AnglerAnalyticsRN/AnglerAnalyticsRN-Swift.h>)
#import <AnglerAnalyticsRN/AnglerAnalyticsRN-Swift.h>
#else
#import "AnglerAnalyticsRN-Swift.h"
#endif

/// TurboModule `AnglerAnalytics`: forwards every spec method to the Swift bridge.
@interface AnglerAnalytics : NSObject <NativeAnglerAnalyticsSpec>
@end

@implementation AnglerAnalytics

RCT_EXPORT_MODULE(AnglerAnalytics)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

// Calls arrive on the main queue so `configure` can read the screen size from UIKit; the
// core does its own work on a background queue.
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)configure:(NSString *)configJson
{
  [AnglerAnalyticsBridge configure:configJson];
}

- (void)track:(NSString *)name
     dataJson:(NSString *_Nullable)dataJson
propertiesJson:(NSString *_Nullable)propertiesJson
      eventId:(NSString *_Nullable)eventId
{
  [AnglerAnalyticsBridge track:name dataJson:dataJson propertiesJson:propertiesJson eventId:eventId];
}

- (void)handleDeepLink:(NSString *)url
{
  [AnglerAnalyticsBridge handleDeepLink:url];
}

- (void)setUserId:(NSString *_Nullable)userId
{
  [AnglerAnalyticsBridge setUserId:userId];
}

- (void)setIdentifier:(NSString *)name value:(NSString *_Nullable)value
{
  [AnglerAnalyticsBridge setIdentifier:name value:value];
}

- (void)setApplicationTrackingEnabled:(BOOL)enabled
{
  [AnglerAnalyticsBridge setApplicationTrackingEnabled:enabled];
}

- (void)setEnabled:(BOOL)enabled
{
  [AnglerAnalyticsBridge setEnabled:enabled];
}

- (void)flush
{
  [AnglerAnalyticsBridge flush];
}

- (void)reset
{
  [AnglerAnalyticsBridge reset];
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeAnglerAnalyticsSpecJSI>(params);
}

@end
