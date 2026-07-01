// Objective-C bridge that exposes AppleVisIntelligence to React Native's JS bridge.
// Copy both this file and AppleVisIntelligence.swift into the main Xcode target.

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisIntelligence, NSObject)

RCT_EXTERN_METHOD(
  respond:(NSString *)prompt
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  stream:(NSString *)prompt
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
