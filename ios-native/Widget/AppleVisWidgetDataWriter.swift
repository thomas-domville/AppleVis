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

  // Called from JS whenever player state or forum data changes.
  // Keys mirror what AppleVisWidget.swift reads from WidgetData.
  @objc func update(_ data: NSDictionary) {
    defaults?.set(data["nowPlayingTitle"]    as? String ?? "", forKey: "nowPlayingTitle")
    defaults?.set(data["nowPlayingShow"]     as? String ?? "", forKey: "nowPlayingShow")
    defaults?.set(data["nowPlayingProgress"] as? Double ?? 0,  forKey: "nowPlayingProgress")
    defaults?.set(data["unreadForumCount"]   as? Int    ?? 0,  forKey: "unreadForumCount")
    defaults?.set(data["savedItemCount"]     as? Int    ?? 0,  forKey: "savedItemCount")
    // Tell WidgetKit to re-query all widget timelines so the UI refreshes.
    WidgetCenter.shared.reloadAllTimelines()
  }
}
