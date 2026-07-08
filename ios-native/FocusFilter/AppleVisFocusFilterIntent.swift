// Focus Filter for AppleVis.
//
// Appears automatically in Settings → Focus → [mode] → App Filters once
// compiled into the app — no JS registration call is needed or possible;
// iOS discovers SetFocusFilterIntent conformers and invokes perform()
// directly whenever the user changes the filter in Settings.
//
// perform() persists the chosen categories to the shared App Group so a
// future Notification Service Extension could read them to suppress
// deliveries. No such extension exists yet, so this drives the Settings UI
// but doesn't yet silence any notifications on its own.

import AppIntents
import Foundation

enum AppleVisNotificationCategory: String, AppEnum {
  case forumReply
  case mention
  case newEpisode
  case appUpdate

  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Notification Category"
  static var caseDisplayRepresentations: [AppleVisNotificationCategory: DisplayRepresentation] = [
    .forumReply: "Forum Replies",
    .mention: "Mentions",
    .newEpisode: "New Episodes",
    .appUpdate: "App Updates",
  ]
}

struct AppleVisFocusFilterIntent: SetFocusFilterIntent {
  static var title: LocalizedStringResource = "AppleVis"
  static var description = IntentDescription(
    "Choose which AppleVis notifications break through this Focus."
  )

  @Parameter(title: "Allowed notification categories")
  var allowedCategories: [AppleVisNotificationCategory]

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: "group.com.applevis.app")
    defaults?.set(allowedCategories.map { $0.rawValue }, forKey: "focusFilterAllowedCategories")
    return .result()
  }
}
