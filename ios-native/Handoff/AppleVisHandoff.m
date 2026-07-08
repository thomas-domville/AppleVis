#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisHandoff, NSObject)

RCT_EXTERN_METHOD(
  advertise:(NSString *)activityType
  title:(NSString *)title
  webpageURL:(NSString *)webpageURL
  userInfo:(NSDictionary *)userInfo
)

RCT_EXTERN_METHOD(resign)

@end
