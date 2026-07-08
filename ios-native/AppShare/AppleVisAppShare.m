#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisAppShare, NSObject)

RCT_EXTERN_METHOD(
  consumePendingURL:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  consumePendingBlogText:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  consumePendingPodcastURL:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
