#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisVision, NSObject)

RCT_EXTERN_METHOD(
  describeImage:(NSString *)imageUrl
  resolver:(RCTPromiseResolveBlock)resolve
  rejecter:(RCTPromiseRejectBlock)reject
)

@end
