// Native module for the App Submission Share flow.
//
// Reads and clears a pending App Store URL written by the AppleVis Share
// Extension into the shared App Group UserDefaults. Called on app foreground
// to catch any URL that arrived before the Linking listener was registered.
//
// App Group: group.com.applevis.app
// UserDefaults key: pendingAppShareURL
//
// After prebuild: copy both this file and AppleVisAppShare.m into the main
// Xcode target (ios/AppleVis/).
// Add App Groups entitlement to both the main app AND the Share Extension:
//   com.apple.security.application-groups = ["group.com.applevis.app"]

import Foundation

@objc(AppleVisAppShare)
class AppleVisAppShare: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  private static let appGroupSuite = "group.com.applevis.app"
  private static let pendingURLKey  = "pendingAppShareURL"

  /// Reads the pending App Store URL written by the Share Extension and
  /// immediately clears it so the next call returns nil.
  /// Returns nil (NSNull) if no URL is waiting.
  @objc func consumePendingURL(
    _ resolve: @escaping RCTPromiseResolveBlock,
      reject:  @escaping RCTPromiseRejectBlock
  ) {
    let defaults = UserDefaults(suiteName: Self.appGroupSuite)
    let url = defaults?.string(forKey: Self.pendingURLKey)
    defaults?.removeObject(forKey: Self.pendingURLKey)
    defaults?.synchronize()
    resolve(url as Any)
  }
}
