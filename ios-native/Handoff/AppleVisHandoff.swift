// Handoff / NSUserActivity for AppleVis.
//
// Advertises the user's current screen to nearby Apple devices (Mac, iPad)
// signed into the same iCloud account. The receiving device shows an
// app-switcher icon; tapping it opens AppleVis (or, if AppleVis isn't
// installed there, falls back to opening webpageURL in Safari).
//
// All activity types advertised by the JS layer must be listed in the main
// target's Info.plist under NSUserActivityTypes — see withHandoff.js.

import Foundation

@objc(AppleVisHandoff)
class AppleVisHandoff: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { true }

  private static var currentActivity: NSUserActivity?

  @objc func advertise(_ activityType: String, title: String, webpageURL: String?, userInfo: [String: String]?) {
    DispatchQueue.main.async {
      let activity = NSUserActivity(activityType: activityType)
      activity.title = title
      activity.isEligibleForHandoff = true
      activity.isEligibleForSearch = true

      if let webpageURL, let url = URL(string: webpageURL) {
        activity.webpageURL = url
      }
      if let userInfo {
        activity.userInfo = userInfo
        activity.requiredUserInfoKeys = Set(userInfo.keys)
      }

      Self.currentActivity = activity
      activity.becomeCurrent()
    }
  }

  @objc func resign() {
    DispatchQueue.main.async {
      Self.currentActivity?.resignCurrent()
      Self.currentActivity = nil
    }
  }
}
