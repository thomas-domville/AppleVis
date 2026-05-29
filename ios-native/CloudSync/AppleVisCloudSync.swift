// NSUbiquitousKeyValueStore bridge for React Native.
// Syncs small values across all of the user's Apple devices via iCloud.
// Falls back gracefully if iCloud is not available.
//
// After prebuild: copy both this file and AppleVisCloudSync.m into the
// main Xcode target (ios/AppleVis/).

import Foundation

@objc(AppleVisCloudSync)
class AppleVisCloudSync: NSObject {

  private let store = NSUbiquitousKeyValueStore.default

  @objc static func requiresMainQueueSetup() -> Bool { false }

  override init() {
    super.init()
    // Listen for changes pushed from other devices
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(storeDidChange(_:)),
      name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: store
    )
    store.synchronize()
  }

  @objc private func storeDidChange(_ notification: Notification) {
    // Trigger a sync so the JS layer picks up remote changes on next read
    store.synchronize()
  }

  // MARK: - JS-callable methods

  @objc func getItem(_ key: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let value = store.string(forKey: key)
    resolve(value)
  }

  @objc func setItem(_ key: String, value: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    store.set(value, forKey: key)
    store.synchronize()
    resolve(nil)
  }

  @objc func removeItem(_ key: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    store.removeObject(forKey: key)
    store.synchronize()
    resolve(nil)
  }

  @objc func getAllKeys(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    let keys = Array(store.dictionaryRepresentation.keys)
    resolve(keys)
  }
}
