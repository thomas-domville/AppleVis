// Objective-C bridge exposing AppleVisCloudSync to the React Native JS bridge.
// Copy both this file and AppleVisCloudSync.swift into the main Xcode target.

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisCloudSync, NSObject)

RCT_EXTERN_METHOD(
  getItem:(NSString *)key
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  setItem:(NSString *)key
  value:(NSString *)value
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  removeItem:(NSString *)key
  resolve:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

RCT_EXTERN_METHOD(
  getAllKeys:(RCTPromiseResolveBlock)resolve
  reject:(RCTPromiseRejectBlock)reject
)

@end
