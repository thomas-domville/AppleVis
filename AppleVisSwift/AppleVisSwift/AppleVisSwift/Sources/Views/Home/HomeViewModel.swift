import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var hasMore = false
    @Published private(set) var newActivitySummary = ""
    @Published private(set) var newItems: [FeedItem] = []
    @Published var isNewActivityDismissed = false
    @Published private(set) var isReturningVisit = false
    /// Display names of sources that failed on the most recent load, e.g.
    /// ["Forums", "Podcasts"]. Non-empty alongside a populated `items` means
    /// a partial failure — some sources loaded fine, these didn't.
    @Published private(set) var failedSourceNames: [String] = []

    private let pageSize = 20
    private var page = 0
    private var lastVisit: Date {
        get { Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "applevis.lastVisit")) }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "applevis.lastVisit") }
    }

    func load() async {
        SoundPlayer.shared.play(.loadingStart)
        isLoading = true
        let hadNoItems = items.isEmpty
        if hadNoItems { error = nil }
        page = 0
        isReturningVisit = UserDefaults.standard.object(forKey: "applevis.lastVisit") != nil

        let (fetched, failed) = await fetchPage(page: 0)
        failedSourceNames = failed

        if fetched.isEmpty && !failed.isEmpty {
            // Total failure. On first load there's nothing to show but the
            // error; on a later refresh, leave whatever's already on screen
            // alone rather than blanking it — the failedSourceNames banner
            // already tells the user something's wrong.
            if hadNoItems {
                error = "Couldn't load Home. Pull to refresh."
            }
        } else {
            error = nil
            items = fetched.sorted { $0.lastActivityAt > $1.lastActivityAt }
            hasMore = fetched.count >= pageSize
            buildNewActivitySummary()
            lastVisit = Date()
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        page += 1
        let (more, _) = await fetchPage(page: page)
        let merged = (items + more).sorted { $0.lastActivityAt > $1.lastActivityAt }
        items = merged
        hasMore = more.count >= pageSize
    }

    // MARK: - Private

    private struct SourceFetchResult {
        let items: [FeedItem]
        let failedName: String?
    }

    /// Runs one source's fetch in isolation so a single failing source
    /// (e.g. Forums down) can't wipe out the other four, which is what
    /// `try await (a, b, c, d, e)` on a tuple of `async let`s would do —
    /// the first throw propagates and every other result, even ones that
    /// already succeeded, gets discarded.
    private func fetchSource(name: String, _ fetch: @escaping () async throws -> [FeedItem]) async -> SourceFetchResult {
        do {
            return SourceFetchResult(items: try await fetch(), failedName: nil)
        } catch {
            return SourceFetchResult(items: [], failedName: name)
        }
    }

    private func fetchPage(page: Int) async -> (items: [FeedItem], failedSources: [String]) {
        // Read preferences from UserDefaults directly to avoid environment dependency
        let showForums   = UserDefaults.standard.object(forKey: "feed.showForums")   as? Bool ?? true
        let showPodcasts = UserDefaults.standard.object(forKey: "feed.showPodcasts") as? Bool ?? true
        let showApps     = UserDefaults.standard.object(forKey: "feed.showApps")     as? Bool ?? true
        let showGuides   = UserDefaults.standard.object(forKey: "feed.showGuides")   as? Bool ?? true
        let showBlogs    = UserDefaults.standard.object(forKey: "feed.showBlogs")    as? Bool ?? true
        let appleOnly    = UserDefaults.standard.object(forKey: "feed.appleOnly")    as? Bool ?? false

        let defaultFilterRaw = UserDefaults.standard.string(forKey: "forums.defaultFilter") ?? ForumFilter.recent.rawValue
        let defaultFilter = ForumFilter(rawValue: defaultFilterRaw) ?? .recent

        async let forums = showForums
            ? fetchSource(name: "Forums") {
                let topics = try await APIClient.shared.forums.recent(page: page, appleOnly: appleOnly)
                // Following/Saved aren't meaningful as a Home-feed filter
                // (Home already mixes several content kinds) — treat them
                // the same as Recent here.
                let filtered = defaultFilter.supportsRefinement ? defaultFilter.apply(to: topics) : topics
                return filtered.map { FeedItem.forumTopic($0) }
              }
            : SourceFetchResult(items: [], failedName: nil)
        async let podcasts = showPodcasts
            ? fetchSource(name: "Podcasts") { try await APIClient.shared.podcasts.episodes(page: page).map { FeedItem.podcastEpisode($0) } }
            : SourceFetchResult(items: [], failedName: nil)
        async let apps = showApps
            ? fetchSource(name: "Apps") { try await APIClient.shared.apps.list(page: page).map { FeedItem.appListing($0) } }
            : SourceFetchResult(items: [], failedName: nil)
        async let guides = showGuides
            ? fetchSource(name: "Guides") { try await APIClient.shared.resources.list(page: page).map { FeedItem.resource($0) } }
            : SourceFetchResult(items: [], failedName: nil)
        async let blogs = showBlogs
            ? fetchSource(name: "Blogs") { try await APIClient.shared.blogs.list(page: page).map { FeedItem.blogPost($0) } }
            : SourceFetchResult(items: [], failedName: nil)

        let results = await [forums, podcasts, apps, guides, blogs]
        var combined: [FeedItem] = []
        var failed: [String] = []
        for result in results {
            combined += result.items
            if let name = result.failedName { failed.append(name) }
        }
        return (combined, failed)
    }

    private func buildNewActivitySummary() {
        let since = lastVisit
        newItems = items.filter { $0.lastActivityAt > since }
        isNewActivityDismissed = false
        guard !newItems.isEmpty else { newActivitySummary = ""; return }
        newActivitySummary = "\(newItems.count) new item\(newItems.count == 1 ? "" : "s") since your last visit"
    }
}
