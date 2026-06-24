// Native module for the AppleVis Share flow.
//
// Reads and clears pending values written by the Share Extension into the
// shared App Group UserDefaults. Call each consumer on app foreground to
// catch content that arrived before the Linking listener was registered.
//
// Keys:
//   pendingAppShareURL  – App Store URL shared via Share Extension
//   pendingBlogText     – Plain text / file content for blog submission
//   pendingPodcastURL   – Podcast URL shared via Share Extension
//
// App Group: group.com.applevis.app

import Foundation

@objc(AppleVisAppShare)
class AppleVisAppShare: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  private static let appGroupSuite       = "group.com.applevis.app"
  private static let pendingURLKey        = "pendingAppShareURL"
  private static let pendingBlogTextKey   = "pendingBlogText"
  private static let pendingPodcastURLKey = "pendingPodcastURL"

  private func consume(key: String, resolve: @escaping RCTPromiseResolveBlock) {
    let defaults = UserDefaults(suiteName: Self.appGroupSuite)
    let value    = defaults?.string(forKey: key)
    defaults?.removeObject(forKey: key)
    defaults?.synchronize()
    resolve(value as Any)
  }

  /// App Store URL → applevis://submit-app
  @objc func consumePendingURL(
    _ resolve: @escaping RCTPromiseResolveBlock,
      reject:  @escaping RCTPromiseRejectBlock
  ) { consume(key: Self.pendingURLKey, resolve: resolve) }

  /// Blog text → applevis://submit-blog
  @objc func consumePendingBlogText(
    _ resolve: @escaping RCTPromiseResolveBlock,
      reject:  @escaping RCTPromiseRejectBlock
  ) { consume(key: Self.pendingBlogTextKey, resolve: resolve) }

  /// Podcast URL → applevis://submit-podcast
  @objc func consumePendingPodcastURL(
    _ resolve: @escaping RCTPromiseResolveBlock,
      reject:  @escaping RCTPromiseRejectBlock
  ) { consume(key: Self.pendingPodcastURLKey, resolve: resolve) }
}
