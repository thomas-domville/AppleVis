import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var items: [FeedItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var hasMore = false
    @Published private(set) var newActivitySummary = ""
    @Published private(set) var isReturningVisit = false

    private let pageSize = 20
    private var page = 0
    private var lastVisit: Date {
        get { Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "applevis.lastVisit")) }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: "applevis.lastVisit") }
    }

    func load() async {
        SoundPlayer.shared.play(.loadingStart)
        isLoading = true
        error = nil
        page = 0
        isReturningVisit = UserDefaults.standard.object(forKey: "applevis.lastVisit") != nil

        do {
            let fetched = try await fetchPage(page: 0)
            items = fetched.sorted { $0.lastActivityAt > $1.lastActivityAt }
            hasMore = fetched.count >= pageSize
            buildNewActivitySummary()
            lastVisit = Date()
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Failed to load feed. Pull to refresh."
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        page += 1
        do {
            let more = try await fetchPage(page: page)
            let merged = (items + more).sorted { $0.lastActivityAt > $1.lastActivityAt }
            items = merged
            hasMore = more.count >= pageSize
        } catch { /* silently ignore pagination errors */ }
    }

    // MARK: - Private

    private func fetchPage(page: Int) async throws -> [FeedItem] {
        // Read preferences from UserDefaults directly to avoid environment dependency
        let showForums   = UserDefaults.standard.object(forKey: "feed.showForums")   as? Bool ?? true
        let showPodcasts = UserDefaults.standard.object(forKey: "feed.showPodcasts") as? Bool ?? true
        let showApps     = UserDefaults.standard.object(forKey: "feed.showApps")     as? Bool ?? true
        let showGuides   = UserDefaults.standard.object(forKey: "feed.showGuides")   as? Bool ?? true
        let showBlogs    = UserDefaults.standard.object(forKey: "feed.showBlogs")    as? Bool ?? true
        let appleOnly    = UserDefaults.standard.object(forKey: "feed.appleOnly")    as? Bool ?? false

        async let forums   = showForums   ? try APIClient.shared.forums.recent(page: page, appleOnly: appleOnly) : []
        async let podcasts = showPodcasts ? try APIClient.shared.podcasts.episodes(page: page) : []
        async let apps     = showApps     ? try APIClient.shared.apps.list(page: page) : []
        async let guides   = showGuides   ? try APIClient.shared.resources.list(page: page) : []
        async let blogs    = showBlogs    ? try APIClient.shared.blogs.list(page: page) : []

        let (f, p, a, g, b) = try await (forums, podcasts, apps, guides, blogs)
        let defaultFilterRaw = UserDefaults.standard.string(forKey: "forums.defaultFilter") ?? ForumFilter.recent.rawValue
        let defaultFilter = ForumFilter(rawValue: defaultFilterRaw) ?? .recent
        // Following/Saved aren't meaningful as a Home-feed filter (Home already
        // mixes several content kinds) — treat them the same as Recent here.
        let filteredForums = defaultFilter.supportsRefinement ? defaultFilter.apply(to: f) : f

        var result: [FeedItem] = []
        result += filteredForums.map { .forumTopic($0) }
        result += p.map { .podcastEpisode($0) }
        result += a.map { .appListing($0) }
        result += g.map { .resource($0) }
        result += b.map { .blogPost($0) }
        return result
    }

    private func buildNewActivitySummary() {
        let since = lastVisit
        let new = items.filter { $0.lastActivityAt > since }
        guard !new.isEmpty else { newActivitySummary = ""; return }
        newActivitySummary = "\(new.count) new item\(new.count == 1 ? "" : "s") since your last visit"
    }
}
