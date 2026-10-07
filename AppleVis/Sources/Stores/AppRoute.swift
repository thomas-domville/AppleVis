import Foundation

/// Every place an "applevis://" link, a Siri or Shortcuts action, or a
/// keyboard shortcut can take someone, as one typed list. Reading a link is
/// a plain function (`init(url:)`), so it's tested without opening anything;
/// `DeepLinkRouter.open(_:)` then does the opening, using the same sheets
/// and tabs as before. An unknown or damaged link is nil and simply does
/// nothing (Adaptive Experience, 2026-10-06).
enum AppRoute: Equatable {
    case home
    /// Home on a chosen view (New, Fetch, Nibbles); `listen` starts Listen
    /// to Fetch once Fetch has loaded.
    case homeView(HomeFeedFilter, listen: Bool)
    case newTopic
    case discover
    case forYou
    case askTheMouse(question: String)
    case contact
    case settings
    case forums(filter: ForumFilter)
    case savedItems
    case search(query: String)
    case whatsNew
    case podcast(PodcastSiriAction)
    case submitApp(url: String?)
    case submitBlog(text: String?)
    case submitPodcast(url: String?)
    case submitPodcastAudio
    case submitBug
    /// A link AppleVis recognises that has nothing to open, such as a
    /// search with no words. Handled (so it isn't passed on to the web) but
    /// does nothing, as before.
    case ignored

    init?(url: URL) {
        guard url.scheme == "applevis" else { return nil }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }

        switch url.host {
        case "home":
            switch value("view") {
            case "all": self = .homeView(.all, listen: false)
            case "new": self = .homeView(.new, listen: false)
            case "fetch": self = .homeView(.fetch, listen: value("listen") == "1")
            case "nibbles": self = .homeView(.mouseRecap, listen: false)
            default: self = .home
            }
        case "new-topic": self = .newTopic
        case "discover": self = .discover
        case "for-you": self = .forYou
        case "ask": self = .askTheMouse(question: value("q") ?? "")
        case "contact": self = .contact
        case "settings": self = .settings
        case "forums":
            self = .forums(filter: value("filter").flatMap(ForumFilter.init(rawValue:)) ?? .recent)
        case "saved": self = .savedItems
        case "search":
            guard let q = value("q"), !q.trimmingCharacters(in: .whitespaces).isEmpty else { self = .ignored; return }
            self = .search(query: q)
        case "whats-new": self = .whatsNew
        case "podcasts":
            switch value("action") {
            case "resume": self = .podcast(.resume)
            case "playLatest": self = .podcast(.playLatest)
            default: self = .ignored
            }
        case "submit-app": self = .submitApp(url: value("url"))
        case "submit-blog": self = .submitBlog(text: value("text"))
        case "submit-podcast": self = .submitPodcast(url: value("url"))
        case "submit-podcast-audio": self = .submitPodcastAudio
        case "submit-bug": self = .submitBug
        default: return nil
        }
    }

    /// The tab a tab route selects.
    var tab: Int? {
        switch self {
        case .home, .homeView: return 0
        case .discover: return 1
        case .forYou: return 2
        default: return nil
        }
    }
}
