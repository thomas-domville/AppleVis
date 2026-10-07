import Foundation
import Combine
import UIKit

/// Resolves Spotlight search-result taps, push notifications, and
/// applevis.com links into in-app navigation. Spotlight identifiers are our
/// own encoding (kind.id). Real applevis.com URLs — Universal Links and
/// links tapped inside posts — go through `AppleVisLinkResolver`, which
/// reads the page's node number to find the native screen; anything it
/// can't resolve still opens in the browser rather than a guessed screen.
@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var pendingContent: (kind: ContentKind, id: String)?
    /// Set alongside `pendingContent` by a card's "Jump to First New
    /// Comment" action (ContentActionsModifier) — tells ContentView's
    /// destination(for:) to open the detail screen with focus already
    /// landing on the first new reply/comment, instead of the top of the
    /// screen like every other route into `pendingContent` (Spotlight,
    /// push notifications, Siri). Kept separate from `pendingContent`
    /// itself rather than widening its tuple, since every other caller of
    /// pendingContent has no such intent and shouldn't need to supply one.
    @Published var pendingContentIntent: ContentOpenIntent?
    @Published var pendingWebURL: URL?
    @Published var pendingSubmit: PendingSubmit?
    @Published var pendingSiriDestination: SiriDestination?
    @Published var pendingPodcastAction: PodcastSiriAction?
    /// "Listen to AppleVis Fetch": Fetch starts reading once it has loaded.
    @Published var pendingListenToFetch = false
    /// "Start a new AppleVis topic": opens the composer over the app.
    @Published var pendingNewTopic = false
    /// Set by the "What's new on AppleVis" Siri shortcut — consumed by
    /// HomeView once it's live (mirrors the podcast-action pattern above:
    /// HomeViewModel is a `@StateObject` owned by HomeView, not a
    /// cross-process-callable singleton, so the intent can't compute and
    /// speak the summary itself — it just opens the app and asks Home to).
    @Published var pendingSpeakWhatsNew = false
    /// Set by the "Ask the AppleVis Mouse" Siri shortcut: ContentView opens
    /// Ask the Mouse with this question already asked.
    @Published var pendingMouseQuestion: PendingMouseQuestion?

    /// A Help article chosen from Spotlight; ContentView opens it.
    @Published var pendingHelpArticle: HelpArticle?

    func handleSpotlight(identifier: String) {
        if let article = SpotlightIndexer.helpArticle(forIdentifier: identifier) {
            pendingHelpArticle = article
            return
        }
        guard let resolved = SpotlightIndexer.parse(identifier: identifier) else { return }
        pendingContent = resolved
    }

    /// True while an AppleVis link is being looked up — drives ContentView's
    /// "Opening…" indicator, and stops a second tap from starting a second
    /// lookup.
    @Published private(set) var isResolvingLink = false

    func handleUniversalLink(_ url: URL) {
        guard AppleVisLinkResolver.isAppleVisURL(url) else { return }
        openAppleVisLink(url)
    }

    /// Opens an applevis.com link on its native screen when it points to
    /// content — a topic, app entry, guide, and so on — and in the browser
    /// otherwise, or if the lookup fails. Used to always go straight to the
    /// browser: Universal Links opened as a web page inside the app, and
    /// links tapped inside posts left the app for Safari entirely.
    /// Requested directly.
    ///
    /// `onUnresolved` decides where a link goes if it isn't content or the
    /// lookup fails — the in-app browser by default (Universal Links), or
    /// whatever the caller did before (a link inside a post passes Safari,
    /// its old behavior, since ContentView's web sheet can't appear over
    /// the detail sheet that link may be sitting in).
    func openAppleVisLink(_ url: URL, onUnresolved: ((URL) -> Void)? = nil) {
        let fallback = onUnresolved ?? { [weak self] in self?.pendingWebURL = $0 }
        guard AppleVisLinkResolver.destination(for: url) != nil else {
            fallback(url)
            return
        }
        guard !isResolvingLink else { return }
        isResolvingLink = true
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Opening link…"))
        Task {
            if let resolved = await AppleVisLinkResolver.resolve(url) {
                pendingContent = resolved
            } else {
                fallback(url)
            }
            isResolvingLink = false
        }
    }

    /// Handles the Share Extension's "applevis://" deep link. Returns
    /// `false` for anything not matching that scheme, so callers can fall
    /// through to `handleUniversalLink`.
    @discardableResult
    func handleCustomScheme(_ url: URL) -> Bool {
        guard let route = AppRoute(url: url) else { return false }
        open(route)
        return true
    }

    /// Opens a typed route: from a link, Siri or Shortcuts, or a keyboard
    /// shortcut. One place, so each way in reaches the same screen the same
    /// way (Adaptive Experience, 2026-10-06).
    func open(_ route: AppRoute) {
        switch route {
        case .home, .discover, .forYou:
            if let tab = route.tab { KeyCommandRouter.current?.selectedTab = tab }
        case .homeView(let view, let listen):
            // Home keeps its view in this same setting, so it switches as
            // if chosen in the view picker.
            UserDefaults.standard.set(view.rawValue, forKey: "home.feedFilter")
            KeyCommandRouter.current?.selectedTab = 0
            if listen { pendingListenToFetch = true }
        case .newTopic:
            pendingNewTopic = true
        case .askTheMouse(let question):
            pendingMouseQuestion = PendingMouseQuestion(text: question)
        case .contact:
            KeyCommandRouter.current?.openContact()
        case .settings:
            KeyCommandRouter.current?.openSettings()
        case .forums(let filter):
            pendingSiriDestination = .forums(filter: filter)
        case .savedItems:
            pendingSiriDestination = .savedItems(filter: nil)
        case .search(let query):
            pendingSiriDestination = .search(query: query)
        case .whatsNew:
            pendingSpeakWhatsNew = true
        case .podcast(let action):
            pendingPodcastAction = action
        case .submitApp(let appURL):
            _ = AppShareConsumer.consumePendingAppStoreURL()
            if let appURL { pendingSubmit = .app(url: appURL) }
        case .submitBlog(let text):
            _ = AppShareConsumer.consumePendingBlogText()
            if let text { pendingSubmit = .blog(text: text) }
        case .submitPodcast(let podURL):
            _ = AppShareConsumer.consumePendingPodcastURL()
            if let podURL { pendingSubmit = .podcast(url: podURL) }
        case .submitPodcastAudio:
            if let (data, fileName) = AppShareConsumer.consumePendingPodcastAudio() {
                pendingSubmit = .podcastAudio(data: data, fileName: fileName)
            }
        case .submitBug:
            pendingSubmit = .bug
        case .ignored:
            break
        }
    }

    /// Fallback for the rare case a Share Extension's `openURL` request
    /// wasn't honored — checked on every foreground (see AppShareConsumer).
    func checkPendingShareExtensionContent() {
        guard pendingSubmit == nil else { return }
        if let url = AppShareConsumer.consumePendingAppStoreURL() {
            pendingSubmit = .app(url: url)
        } else if let text = AppShareConsumer.consumePendingBlogText() {
            pendingSubmit = .blog(text: text)
        } else if let url = AppShareConsumer.consumePendingPodcastURL() {
            pendingSubmit = .podcast(url: url)
        } else if let (data, fileName) = AppShareConsumer.consumePendingPodcastAudio() {
            pendingSubmit = .podcastAudio(data: data, fileName: fileName)
        }
    }
}

struct PendingMouseQuestion: Identifiable {
    let id = UUID()
    let text: String
}

enum ContentOpenIntent {
    case firstNewComment
}

enum PendingSubmit: Identifiable {
    case app(url: String)
    case blog(text: String)
    case podcast(url: String)
    /// A shared audio file (.mp3/.m4a/.wav) headed straight into the audio
    /// slot a manual "Choose Audio File" pick would fill — see
    /// `AppShareConsumer.consumePendingPodcastAudio()`.
    case podcastAudio(data: Data, fileName: String)
    /// The "Report an AppleVis bug" Siri shortcut — no pre-filled payload,
    /// just opens straight to the blank wizard (which handles its own
    /// sign-in gate if needed).
    case bug

    var id: String {
        switch self {
        case .app(let url): return "app:\(url)"
        case .blog(let text): return "blog:\(text.prefix(40))"
        case .podcast(let url): return "podcast:\(url)"
        case .podcastAudio(let data, let fileName): return "podcastAudio:\(fileName):\(data.count)"
        case .bug: return "bug"
        }
    }
}

/// Destinations reachable via Siri/App Intents that don't map to existing
/// tab navigation, so they're presented as a sheet from ContentView — the
/// same treatment Settings (Cmd+,) already gets from KeyCommandRouter.
enum SiriDestination: Identifiable {
    case forums(filter: ForumFilter)
    /// `filter` pre-selects a kind within Saved — used by Profile's saved-
    /// count rows to jump straight into e.g. just-saved-forum-topics
    /// (matches RN's `?section=saved&savedType=forumTopic` deep link,
    /// foryou.tsx ~1093-1105) instead of always landing on "All".
    case savedItems(filter: ContentKind?)
    case search(query: String)

    var id: String {
        switch self {
        case .forums(let filter): return "forums:\(filter.rawValue)"
        case .savedItems(let filter): return "saved:\(filter?.rawValue ?? "all")"
        case .search(let query): return "search:\(query)"
        }
    }
}

enum PodcastSiriAction: Equatable {
    case resume
    case playLatest
}
