import Foundation
import Combine

/// Resolves Spotlight search-result taps and (best-effort) universal links
/// into in-app navigation. Spotlight identifiers are our own encoding
/// (kind.id), so those resolve reliably. Real applevis.com URLs from
/// Universal Links don't map to a fetchable JSON:API id without a
/// path-alias-resolution endpoint this app doesn't implement — those open in
/// an in-app browser instead of a fabricated (and likely wrong) deep link.
@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var pendingContent: (kind: ContentKind, id: String)?
    @Published var pendingWebURL: URL?
    @Published var pendingSubmit: PendingSubmit?
    @Published var pendingSiriDestination: SiriDestination?
    @Published var pendingPodcastAction: PodcastSiriAction?

    func handleSpotlight(identifier: String) {
        guard let resolved = SpotlightIndexer.parse(identifier: identifier) else { return }
        pendingContent = resolved
    }

    func handleUniversalLink(_ url: URL) {
        // `.contains` would also match a spoofed host like
        // "applevis.com.attacker.com" — iOS's own universal-link domain
        // verification already restricts which real domains can reach this
        // handler at all, but the check itself should still be precise.
        guard let host = url.host, host == "applevis.com" || host.hasSuffix(".applevis.com") else { return }
        pendingWebURL = url
    }

    /// Handles the Share Extension's "applevis://" deep link. Returns
    /// `false` for anything not matching that scheme, so callers can fall
    /// through to `handleUniversalLink`.
    @discardableResult
    func handleCustomScheme(_ url: URL) -> Bool {
        guard url.scheme == "applevis" else { return false }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }

        switch url.host {
        case "submit-app":
            _ = AppShareConsumer.consumePendingAppStoreURL()
            if let appURL = value("url") { pendingSubmit = .app(url: appURL) }
        case "submit-blog":
            _ = AppShareConsumer.consumePendingBlogText()
            if let text = value("text") { pendingSubmit = .blog(text: text) }
        case "submit-podcast":
            _ = AppShareConsumer.consumePendingPodcastURL()
            if let podURL = value("url") { pendingSubmit = .podcast(url: podURL) }
        case "forums":
            let filter = value("filter").flatMap(ForumFilter.init(rawValue:)) ?? .recent
            pendingSiriDestination = .forums(filter: filter)
        case "saved":
            pendingSiriDestination = .savedItems(filter: nil)
        case "search":
            if let query = value("q") { pendingSiriDestination = .search(query: query) }
        case "podcasts":
            switch value("action") {
            case "resume": pendingPodcastAction = .resume
            case "playLatest": pendingPodcastAction = .playLatest
            default: break
            }
        default:
            return false
        }
        return true
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
        }
    }
}

enum PendingSubmit: Identifiable {
    case app(url: String)
    case blog(text: String)
    case podcast(url: String)

    var id: String {
        switch self {
        case .app(let url): return "app:\(url)"
        case .blog(let text): return "blog:\(text.prefix(40))"
        case .podcast(let url): return "podcast:\(url)"
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
