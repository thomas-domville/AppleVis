import AppIntents
import Foundation

/// Appears automatically in Settings → Focus → [mode] → App Filters once
/// compiled into the app — no registration call needed; iOS discovers
/// `SetFocusFilterIntent` conformers and invokes `perform()` directly
/// whenever the user changes the filter in Settings.
///
/// Mirrors the category set `PushNotificationManager.registerCategories()`
/// registers. Persists the chosen categories to the shared App Group so a
/// future Notification Service Extension can read them to suppress
/// deliveries — no such extension exists yet, so this drives the Focus
/// Settings UI but doesn't silence notifications on its own yet.
enum AppleVisNotificationCategory: String, AppEnum {
    case forumReply
    case mention
    case newTopic
    case followedTopic
    case newEpisode
    case appUpdate
    case newResource
    case announcement

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Notification Category"
    static var caseDisplayRepresentations: [AppleVisNotificationCategory: DisplayRepresentation] = [
        .forumReply: "Forum Replies",
        .mention: "Mentions",
        .newTopic: "New Topics",
        .followedTopic: "Followed Topics",
        .newEpisode: "New Episodes",
        .appUpdate: "App Updates",
        .newResource: "New Resources",
        .announcement: "Announcements",
    ]
}

struct AppleVisFocusFilterIntent: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "AppleVis"
    static var description = IntentDescription(
        "Choose which AppleVis notifications break through this Focus."
    )

    // SetFocusFilterIntent requires every parameter to be Optional.
    @Parameter(title: "Allowed notification categories")
    var allowedCategories: [AppleVisNotificationCategory]?

    var displayRepresentation: DisplayRepresentation {
        let categories = allowedCategories ?? []
        return DisplayRepresentation(
            title: "AppleVis",
            subtitle: categories.isEmpty
                ? "All notifications silenced"
                : "\(categories.count) categor\(categories.count == 1 ? "y" : "ies") allowed"
        )
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.applevis.app")
        defaults?.set((allowedCategories ?? []).map(\.rawValue), forKey: "focusFilterAllowedCategories")
        return .result()
    }
}
