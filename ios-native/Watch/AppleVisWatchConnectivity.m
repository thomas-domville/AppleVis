#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(AppleVisWatchConnectivity, RCTEventEmitter)

RCT_EXTERN_METHOD(update:(NSDictionary *)snapshot)

@end
