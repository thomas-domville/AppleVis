// Phone-side WatchConnectivity bridge for the AppleVis Watch app
// (ios-native/Watch/AppleVisWatchApp.swift, a separate watchOS target).
//
// Pushes Now Playing + unread forum count to the watch via
// updateApplicationContext (latest-value-wins, delivered even if the watch
// app isn't currently running) and answers the watch's "requestState"
// message with the same cached snapshot. Play/pause/skip messages sent
// from the watch are re-emitted as the "onWatchAction" JS event.

import Foundation
import WatchConnectivity
import React

@objc(AppleVisWatchConnectivity)
class AppleVisWatchConnectivity: RCTEventEmitter, WCSessionDelegate {

  private var lastContext: [String: Any] = [:]

  override init() {
    super.init()
    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
  }

  @objc static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! { ["onWatchAction"] }

  /// Accepts a *partial* snapshot — only the keys present are overwritten,
  /// so the player can push Now Playing fields without knowing the current
  /// unread count, and vice versa. Keys match WatchModel.applyState(_:)
  /// in AppleVisWatchApp.swift: episodeId, episodeTitle, showTitle,
  /// progress, isPlaying, unreadCount.
  @objc func update(_ snapshot: [String: Any]) {
    guard WCSession.isSupported() else { return }
    for (key, value) in snapshot { lastContext[key] = value }
    guard WCSession.default.activationState == .activated else { return }
    try? WCSession.default.updateApplicationContext(lastContext)
  }

  // MARK: WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    guard let action = message["action"] as? String else { replyHandler([:]); return }

    if action == "requestState" {
      replyHandler(lastContext)
      return
    }

    DispatchQueue.main.async {
      self.sendEvent(withName: "onWatchAction", body: ["action": action])
    }
    replyHandler([:])
  }
}
