#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(AppleVisKeyboardShortcuts, RCTEventEmitter)

RCT_EXTERN_METHOD(registerShortcuts:(NSArray *)shortcuts)

@end
