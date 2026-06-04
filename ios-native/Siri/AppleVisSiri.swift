// Siri App Intents for AppleVis.
// Registers voice phrases so users can say things like:
//   "Hey Siri, open AppleVis Forums"
//   "Hey Siri, play the latest AppleVis podcast"
//   "Hey Siri, show unread AppleVis topics"
//
// AppIntents are discovered automatically by the system — no bridge or JS call needed.
// After prebuild: copy this file into the main Xcode target (ios/AppleVis/).
// Requires iOS 16+ and the Siri entitlement (already in app.config.ts).

import AppIntents
import Foundation

// MARK: - Open Forums

struct OpenAppleVisForumsIntent: AppIntent {
  static var title: LocalizedStringResource = "Open AppleVis Forums"
  static var description = IntentDescription("Opens the AppleVis Forums tab.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    // The app opens via openAppWhenRun; the URL scheme navigates to the right tab.
    await UIApplication.shared.open(URL(string: "applevis://forums")!)
    return .result()
  }
}

// MARK: - Show Unread Topics

struct ShowUnreadTopicsIntent: AppIntent {
  static var title: LocalizedStringResource = "Show Unread AppleVis Topics"
  static var description = IntentDescription("Opens AppleVis and shows unread forum topics.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await UIApplication.shared.open(URL(string: "applevis://forums?filter=Unread")!)
    return .result()
  }
}

// MARK: - Play Latest Podcast

struct PlayLatestPodcastIntent: AppIntent {
  static var title: LocalizedStringResource = "Play Latest AppleVis Podcast"
  static var description = IntentDescription("Opens the Podcasts tab and plays the latest episode.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await UIApplication.shared.open(URL(string: "applevis://podcasts?action=playLatest")!)
    return .result()
  }
}

// MARK: - Open Saved Items

struct OpenSavedItemsIntent: AppIntent {
  static var title: LocalizedStringResource = "Open AppleVis Saved Items"
  static var description = IntentDescription("Opens your saved AppleVis items.")
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await UIApplication.shared.open(URL(string: "applevis://saved")!)
    return .result()
  }
}

// MARK: - App Shortcuts (the phrases Siri recognises without training)

struct AppleVisShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: OpenAppleVisForumsIntent(),
      phrases: [
        "Open \(.applicationName) Forums",
        "Show \(.applicationName) Forums",
        "Go to \(.applicationName) Forums",
      ],
      shortTitle: "Open Forums",
      systemImageName: "bubble.left.and.bubble.right.fill"
    )
    AppShortcut(
      intent: ShowUnreadTopicsIntent(),
      phrases: [
        "Show unread \(.applicationName) topics",
        "Open \(.applicationName) unread",
        "What's unread on \(.applicationName)",
      ],
      shortTitle: "Unread Topics",
      systemImageName: "envelope.badge.fill"
    )
    AppShortcut(
      intent: PlayLatestPodcastIntent(),
      phrases: [
        "Play the latest \(.applicationName) podcast",
        "Play \(.applicationName) podcast",
        "Start \(.applicationName) podcast",
      ],
      shortTitle: "Play Latest Podcast",
      systemImageName: "radio.fill"
    )
    AppShortcut(
      intent: OpenSavedItemsIntent(),
      phrases: [
        "Open my \(.applicationName) saved items",
        "Show \(.applicationName) saved",
      ],
      shortTitle: "Saved Items",
      systemImageName: "bookmark.fill"
    )
  }
}
