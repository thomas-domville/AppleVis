#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(AppleVisCarPlay, RCTEventEmitter)

RCT_EXTERN_METHOD(updateEpisodes:(NSArray *)items)

@end
