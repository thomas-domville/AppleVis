#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisWidgetDataWriter, NSObject)

RCT_EXTERN_METHOD(update:(NSDictionary *)data)

RCT_EXTERN_METHOD(
  consumePendingAction:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
