// Main-app controller for Live Activities.
// Starts, updates, and ends the podcast playback Live Activity shown on the
// Lock Screen and Dynamic Island. The extension target (AppleVisLiveActivity.swift)
// handles rendering; this file handles lifecycle from the JS side.
//
// After prebuild: copy BOTH this file and AppleVisLiveActivityController.m into
// the main Xcode target (ios/AppleVis/). The extension target already has its own
// copy of AppleVisPodcastAttributes.

import ActivityKit
import Foundation

// Must stay in sync with the struct defined in AppleVisLiveActivity.swift (extension target).
struct AppleVisPodcastAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var isPlaying: Bool
    var positionSeconds: Double
    var durationSeconds: Double
    var speed: Double
    var chapterTitle: String
  }
  var episodeTitle: String
  var showTitle: String
  var episodeId: String
}

@objc(AppleVisLiveActivityController)
class AppleVisLiveActivityController: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  private var activity: Activity<AppleVisPodcastAttributes>?

  @objc func start(_ params: NSDictionary) {
    guard #available(iOS 16.2, *) else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let attrs = AppleVisPodcastAttributes(
      episodeTitle: params["episodeTitle"] as? String ?? "",
      showTitle:    params["showTitle"]    as? String ?? "",
      episodeId:    params["episodeId"]    as? String ?? ""
    )
    let state = AppleVisPodcastAttributes.ContentState(
      isPlaying:       params["isPlaying"]  as? Bool   ?? false,
      positionSeconds: params["position"]   as? Double ?? 0,
      durationSeconds: params["duration"]   as? Double ?? 0,
      speed:           params["speed"]      as? Double ?? 1.0,
      chapterTitle:    params["chapterTitle"] as? String ?? ""
    )
    Task {
      do {
        activity = try Activity.request(attributes: attrs, contentState: state, pushType: nil)
      } catch {
        print("[LiveActivity] start error: \(error)")
      }
    }
  }

  @objc func update(_ params: NSDictionary) {
    guard #available(iOS 16.2, *) else { return }
    let state = AppleVisPodcastAttributes.ContentState(
      isPlaying:       params["isPlaying"]    as? Bool   ?? false,
      positionSeconds: params["position"]     as? Double ?? 0,
      durationSeconds: params["duration"]     as? Double ?? 0,
      speed:           params["speed"]        as? Double ?? 1.0,
      chapterTitle:    params["chapterTitle"] as? String ?? ""
    )
    Task { await activity?.update(using: state) }
  }

  @objc func end() {
    guard #available(iOS 16.2, *) else { return }
    Task {
      await activity?.end(dismissalPolicy: .immediate)
      activity = nil
    }
  }
}
