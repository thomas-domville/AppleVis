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
    static var description = IntentDescription("Opens AppleVis Forums.")
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
    static var description = IntentDescription("Opens AppleVis Podcasts and plays the latest episode.")
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

/// Opens Home on New: the new posts and comments you haven't read, across
/// every kind of content. It used to read Home's summary aloud after
/// opening the app, which opening the app already shows; New is what
/// people want when they ask what's new (2026-10-06).
struct WhatsNewOnAppleVisIntent: AppIntent {
    static var title: LocalizedStringResource = "What's New on AppleVis"
    static var description = IntentDescription(
        "Opens Home on New, with the new posts and comments you haven't read yet."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://home?view=new")!)
        return .result()
    }
}

/// Opens Fetch and starts Listen to Fetch: everything new, read aloud,
/// without touching the screen (2026-10-06).
struct ListenToFetchIntent: AppIntent {
    static var title: LocalizedStringResource = "Listen to AppleVis Fetch"
    static var description = IntentDescription(
        "Opens Fetch on Home and reads everything new aloud."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://home?view=fetch&listen=1")!)
        return .result()
    }
}

/// Opens Home on Nibbles, for the period last chosen there (2026-10-06).
struct OpenNibblesIntent: AppIntent {
    static var title: LocalizedStringResource = "Open AppleVis Nibbles"
    static var description = IntentDescription(
        "Opens Nibbles on Home, a summary of recent activity on AppleVis."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://home?view=nibbles")!)
        return .result()
    }
}

/// Opens the composer for a new forum topic, ready for dictation
/// (2026-10-06).
struct StartNewTopicIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a New AppleVis Topic"
    static var description = IntentDescription(
        "Opens the composer to start a new forum topic."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://new-topic")!)
        return .result()
    }
}

struct ReportBugToAppleVisIntent: AppIntent {
    static var title: LocalizedStringResource = "Report an AppleVis Bug"
    static var description = IntentDescription(
        "Opens AppleVis straight to the accessibility bug report form."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://submit-bug")!)
        return .result()
    }
}

/// Opens Ask the Mouse with the question already asked. Requested
/// directly (2026-09-28).
struct AskTheMouseIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask the AppleVis Mouse"
    static var description = IntentDescription(
        "Asks the Mouse a question about AppleVis, the app, or apps and guides on the site."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question", description: "What you'd like to ask the Mouse.")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult {
        var components = URLComponents()
        components.scheme = "applevis"
        components.host = "ask"
        components.queryItems = [URLQueryItem(name: "q", value: question)]
        if let url = components.url {
            _ = await UIApplication.shared.open(url)
        }
        return .result()
    }
}

/// Opens the Contact AppleVis form (2026-10-06).
struct ContactAppleVisIntent: AppIntent {
    static var title: LocalizedStringResource = "Contact AppleVis"
    static var description = IntentDescription(
        "Opens the Contact AppleVis form, to ask a question or send feedback to the AppleVis team."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        _ = await UIApplication.shared.open(URL(string: "applevis://contact")!)
        return .result()
    }
}

/// The spoken Siri phrases, in the order the Shortcuts app and Spotlight
/// show them: grouped, with the biggest features first. Chosen with the
/// user (2026-10-06). Open AppleVis, Forums, Unread Topics, Saved Items and
/// Report a Bug no longer have phrases ("Open AppleVis" works for any app
/// anyway); they're still actions in the Shortcuts app. An app may have
/// ten; one is left free for a future feature. Keep Help's "Siri and
/// Spotlight" article in the same order.
struct AppleVisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Ask and find
        AppShortcut(
            intent: AskTheMouseIntent(),
            phrases: [
                "Ask the \(.applicationName) Mouse",
                "Ask \(.applicationName) Mouse a question",
                "Ask \(.applicationName) a question",
            ],
            shortTitle: "Ask the Mouse",
            systemImageName: "questionmark.bubble.fill"
        )
        // A plain String @Parameter can't be embedded in a phrase on this
        // SDK, so Siri asks for the search words after the phrase.
        AppShortcut(
            intent: SearchAppleVisIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find something on \(.applicationName)",
                "Look something up on \(.applicationName)",
            ],
            shortTitle: "Search AppleVis",
            systemImageName: "magnifyingglass"
        )
        // Catching up on Home
        AppShortcut(
            intent: WhatsNewOnAppleVisIntent(),
            phrases: [
                "What's new on \(.applicationName)",
                "Catch me up on \(.applicationName)",
                "\(.applicationName) update",
            ],
            shortTitle: "What's New",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: ListenToFetchIntent(),
            phrases: [
                "Listen to \(.applicationName) Fetch",
                "Read me \(.applicationName) Fetch",
                "Play \(.applicationName) Fetch",
            ],
            shortTitle: "Listen to Fetch",
            systemImageName: "dog.fill"
        )
        AppShortcut(
            intent: OpenNibblesIntent(),
            phrases: [
                "Open \(.applicationName) Nibbles",
                "Show me \(.applicationName) Nibbles",
            ],
            shortTitle: "Nibbles",
            systemImageName: "newspaper.fill"
        )
        // Podcasts
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
        // Posting and getting in touch
        AppShortcut(
            intent: StartNewTopicIntent(),
            phrases: [
                "Start a new \(.applicationName) topic",
                "Post on \(.applicationName)",
                "New \(.applicationName) topic",
            ],
            shortTitle: "New Topic",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: ContactAppleVisIntent(),
            phrases: [
                "Contact \(.applicationName)",
                "Send feedback to \(.applicationName)",
                "Report a problem with \(.applicationName)",
            ],
            shortTitle: "Contact AppleVis",
            systemImageName: "envelope.fill"
        )
    }
}
