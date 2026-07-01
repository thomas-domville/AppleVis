// Objective-C bridge that exposes AppleVisNowPlaying to React Native's JS bridge.
// Copy both this file and AppleVisNowPlaying.swift into the main Xcode target.

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(AppleVisNowPlaying, NSObject)

RCT_EXTERN_METHOD(
  updateNowPlaying:(NSString *)title
  artist:(NSString *)artist
  albumTitle:(NSString *)albumTitle
  duration:(double)duration
  position:(double)position
  speed:(double)speed
  isPlaying:(BOOL)isPlaying
  artworkURLString:(NSString *)artworkURLString
)

RCT_EXTERN_METHOD(
  setupRemoteCommands:(RCTResponseSenderBlock)onPlay
  onPause:(RCTResponseSenderBlock)onPause
  onTogglePlayPause:(RCTResponseSenderBlock)onTogglePlayPause
  onSkipBackward:(RCTResponseSenderBlock)onSkipBackward
  onSkipForward:(RCTResponseSenderBlock)onSkipForward
  onSeek:(RCTResponseSenderBlock)onSeek
  onNextTrack:(RCTResponseSenderBlock)onNextTrack
  onPreviousTrack:(RCTResponseSenderBlock)onPreviousTrack
  skipBackInterval:(double)skipBackInterval
  skipForwardInterval:(double)skipForwardInterval
)

RCT_EXTERN_METHOD(clearNowPlaying)

@end
