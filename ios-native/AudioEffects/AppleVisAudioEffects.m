#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisAudioEffects, NSObject)

RCT_EXTERN_METHOD(setVoiceBoost:(BOOL)enabled)
RCT_EXTERN_METHOD(setTrimSilence:(BOOL)enabled)

@end
