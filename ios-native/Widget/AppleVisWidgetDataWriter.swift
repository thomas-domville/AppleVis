// Writes widget data from the main app into the shared App Group UserDefaults
// so the WidgetKit extension can read it and refresh the Home/Lock Screen widgets.
// After prebuild: copy both this file and AppleVisWidgetDataWriter.m into the
// main Xcode target (ios/AppleVis/).

import Foundation
import WidgetKit

@objc(AppleVisWidgetDataWriter)
class AppleVisWidgetDataWriter: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  private let defaults = UserDefaults(suiteName: "group.com.applevis.app")

  // Called from JS whenever player state or forum data changes. JS sends a
  // *partial* snapshot (e.g. just the player fields, or just the unread
  // count) — only set keys that are actually present so an update from one
  // source doesn't clobber values written by another with defaults.
  // Keys mirror what AppleVisWidget.swift reads from WidgetData.
  @objc func update(_ data: NSDictionary) {
    if let v = data["nowPlayingTitle"]    as? String { defaults?.set(v, forKey: "nowPlayingTitle") }
    if let v = data["nowPlayingShow"]     as? String { defaults?.set(v, forKey: "nowPlayingShow") }
    if let v = data["nowPlayingProgress"] as? Double { defaults?.set(v, forKey: "nowPlayingProgress") }
    if let v = data["isPlaying"]          as? Bool   { defaults?.set(v, forKey: "isPlaying") }
    if let v = data["unreadForumCount"]   as? Int    { defaults?.set(v, forKey: "unreadForumCount") }
    if let v = data["savedItemCount"]     as? Int    { defaults?.set(v, forKey: "savedItemCount") }
    // Tell WidgetKit to re-query all widget timelines so the UI refreshes.
    WidgetCenter.shared.reloadAllTimelines()
  }

  // Reads and clears the action written by the widget's interactive
  // AppIntents (WidgetTogglePlayPauseIntent, TogglePodcastControlIntent,
  // OpenForumsControlIntent) — those run inside the extension, which can't
  // call UIApplication.shared.open(_:), so they leave a signal here instead.
  // Called from JS on app foreground; openAppWhenRun already brings the app
  // forward, this is what lets the app act on *why* it was brought forward.
  @objc func consumePendingAction(
    _ resolve: @escaping RCTPromiseResolveBlock,
      reject:  @escaping RCTPromiseRejectBlock
  ) {
    let action = defaults?.string(forKey: "pendingWidgetAction")
    defaults?.removeObject(forKey: "pendingWidgetAction")
    resolve(action as Any)
  }
}
