#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisSpotlight, NSObject)

RCT_EXTERN_METHOD(
  index:(NSArray *)items
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  deindex:(NSString *)identifier
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  deindexAll:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
