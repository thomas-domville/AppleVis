import Foundation
import UserNotifications

/// Reads, never changes, how the person's own AppleVis app is set up for
/// one settings screen, so the Mouse can answer "Why don't I get
/// notifications?" with what's actually switched off. Read on the device
/// and given only to Apple Intelligence on the device; never sent anywhere.
/// The lines are for the model, in English, with setting names as the
/// person sees them. Requested directly (2026-10-01).
enum MouseSetupCheck {
    static func facts(for place: MousePlace, preferences: PreferencesStore, isSignedIn: Bool) async -> String {
        var lines: [String] = []
        func state(_ name: String, _ isOn: Bool) {
            lines.append("\"\(name)\" is \(isOn ? "on" : "off").")
        }
        switch place {
        case .notificationSettings:
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            switch status {
            case .denied: lines.append("Notifications for AppleVis are turned off in iOS Settings, so none can arrive until they're allowed there.")
            case .notDetermined: lines.append("AppleVis hasn't been given permission for notifications yet.")
            default: lines.append("Notifications for AppleVis are allowed in iOS Settings.")
            }
            lines.append(isSignedIn ? "The person is signed in." : "The person isn't signed in, and replies and followed-topic alerts need them to be.")
            state(String(localized: "Replies to My Posts"), preferences.notifyForumReplies)
            state(String(localized: "Followed Topics"), preferences.notifyFollowedTopics)
            state(String(localized: "New Forum Topics"), preferences.notifyNewTopics)
            state(String(localized: "New App Directory Entries"), preferences.notifyAppUpdates)
            state(String(localized: "New Podcast Episodes"), preferences.notifyNewEpisodes)
            state(String(localized: "New Guides"), preferences.notifyNewResources)
            state(String(localized: "New Comments"), preferences.notifyNewComments)
            state(String(localized: "Badge Count"), preferences.badgeCountEnabled)
        case .savedSyncSettings:
            lines.append(FileManager.default.ubiquityIdentityToken == nil
                ? "This device isn't signed in to iCloud, so nothing can sync."
                : "This device is signed in to iCloud.")
            state(String(localized: "Enable iCloud Sync"), preferences.iCloudSync)
            state(String(localized: "Saved Items"), preferences.savedItemsSync)
            state(String(localized: "Following"), preferences.followedItemsSync)
            state(String(localized: "Podcast Position"), preferences.podcastPositionSync)
            state(String(localized: "Podcast Queue"), preferences.queueSync)
            state(String(localized: "Read History"), preferences.readHistorySync)
            state(String(localized: "Settings & Preferences"), preferences.settingsSync)
        case .contentTranslationSettings:
            state(String(localized: "Auto-Translate Content"), preferences.autoTranslateEnabled)
        default:
            break
        }
        // The on/off settings the Mouse knows on that screen.
        for mouseSwitch in MouseSwitch.allCases where mouseSwitch.place == place {
            state(mouseSwitch.name, preferences[keyPath: mouseSwitch.keyPath])
        }
        return lines.joined(separator: "\n")
    }
}
