import AppIntents
import UIKit

/// Siri/Shortcuts support. `PlayerStore` is a single `@StateObject` owned by
/// the app's root view, not a cross-process-callable singleton, so an intent
/// can't call into it directly — instead these open the "applevis://" URL
/// scheme (the same one the Share Extension uses), which `AppleVisApp`'s
/// `.onOpenURL` → `DeepLinkRouter` already routes into real navigation/player
/// actions once the app is foregrounded. `openAppWhenRun` alone brings the
/// app forward but carries no payload, so the explicit `open(_:)` call is
/// still needed to pass along the destination/query/action.
struct OpenAppleVisIntent: AppIntent {
    static var title: LocalizedStringResource = "Open AppleVis"
    static var description = IntentDescription("Opens AppleVis to the Home tab.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OpenAppleVisForumsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open AppleVis Forums"
    static var description = IntentDescription("Opens the AppleVis Forums tab.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://forums")!)
        return .result()
    }
}

struct ShowUnreadTopicsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Unread AppleVis Topics"
    static var description = IntentDescription("Opens AppleVis and shows unread forum topics.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://forums?filter=unread")!)
        return .result()
    }
}

struct ResumeAppleVisPodcastIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume AppleVis Podcast"
    static var description = IntentDescription(
        "Resumes the last-played AppleVis podcast episode from where you left off."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://podcasts?action=resume")!)
        return .result()
    }
}

struct PlayLatestPodcastIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Latest AppleVis Podcast"
    static var description = IntentDescription("Opens the Podcasts tab and plays the latest episode.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://podcasts?action=playLatest")!)
        return .result()
    }
}

struct SearchAppleVisIntent: AppIntent {
    static var title: LocalizedStringResource = "Search AppleVis"
    static var description = IntentDescription(
        "Searches AppleVis for forum topics, apps, podcast episodes, or guides."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Search Query", description: "What to search for on AppleVis.")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        _ = await UIApplication.shared.open(URL(string: "applevis://search?q=\(encoded)")!)
        return .result()
    }
}

struct OpenSavedItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open AppleVis Saved Items"
    static var description = IntentDescription("Opens your saved AppleVis items.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://saved")!)
        return .result()
    }
}

struct AppleVisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenAppleVisIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open \(.applicationName) app",
            ],
            shortTitle: "Open AppleVis",
            systemImageName: "eye"
        )
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
            intent: ResumeAppleVisPodcastIntent(),
            phrases: [
                "Resume my \(.applicationName) podcast",
                "Continue \(.applicationName) podcast",
                "Keep playing \(.applicationName)",
            ],
            shortTitle: "Resume Podcast",
            systemImageName: "play.circle.fill"
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
            intent: SearchAppleVisIntent(),
            // Confirmed via the AppIntents metadata compiler itself
            // ("'AppEntity' and 'AppEnum' are the only allowed types for
            // 'query'") — a plain String @Parameter genuinely can't be
            // embedded in a phrase on this SDK, so RN's equivalent phrases
            // (which did embed their query parameter) aren't reproducible
            // here. Siri still prompts for `query` conversationally after
            // one of these static phrases.
            phrases: [
                "Search \(.applicationName)",
                "Find something on \(.applicationName)",
                "Look something up on \(.applicationName)",
            ],
            shortTitle: "Search AppleVis",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OpenSavedItemsIntent(),
            phrases: [
                "Open my \(.applicationName) saved items",
                "Show \(.applicationName) saved",
                "My \(.applicationName) bookmarks",
            ],
            shortTitle: "Saved Items",
            systemImageName: "bookmark.fill"
        )
    }
}
