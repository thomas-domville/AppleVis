#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisLiveActivityController, NSObject)

RCT_EXTERN_METHOD(start:(NSDictionary *)params)
RCT_EXTERN_METHOD(update:(NSDictionary *)params)
RCT_EXTERN_METHOD(end)

@end
