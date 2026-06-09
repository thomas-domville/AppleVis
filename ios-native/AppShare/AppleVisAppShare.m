#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisAppShare, NSObject)

RCT_EXTERN_METHOD(
  consumePendingURL:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
