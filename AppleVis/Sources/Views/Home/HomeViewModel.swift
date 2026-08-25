import Foundation
import Combine
import UIKit

/// Lets the Home tab's unread count reach the tab bar badge in ContentView
/// without hoisting HomeViewModel's whole lifecycle up to the app root —
/// same singleton-`ObservedObject` pattern already used by ToastStore/
/// NetworkStatusStore for cross-screen state that isn't worth an explicit
/// ownership chain.
@MainActor
final class HomeBadgeStore: ObservableObject {
    static let shared = HomeBadgeStore()
    @Published var unreadForumTopicCount = 0
    private init() {}
}

struct MouseRecapDigest: Codable {
    let startDate: Date
    let endDate: Date
    let generatedAt: Date
    let apps: [AppListing]
    let podcasts: [PodcastEpisode]
    let forums: [ForumTopic]
    let resources: [Resource]
    let blogs: [BlogPost]

    var isEmpty: Bool {
        apps.isEmpty && podcasts.isEmpty && forums.isEmpty && resources.isEmpty && blogs.isEmpty
    }

    var countSummary: String {
        let parts = [
            Self.countPart(apps.count, singular: "accessible app", plural: "accessible apps"),
            Self.countPart(podcasts.count, singular: "podcast episode", plural: "podcast episodes"),
            Self.countPart(forums.count, singular: "popular discussion", plural: "popular discussions"),
            Self.countPart(resources.count, singular: "guide or tutorial", plural: "guides and tutorials"),
            Self.countPart(blogs.count, singular: "blog post", plural: "blog posts"),
        ].compactMap { $0 }
        return parts.isEmpty ? "No recap items found for this period." : parts.joined(separator: " · ")
    }

    var dateRangeText: String {
        let start = startDate.formatted(date: .abbreviated, time: .omitted)
        let end = endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(start)-\(end)"
    }

    var shareText: String {
        var lines = [
            "Mouse Recap",
            dateRangeText,
            "",
            countSummary,
        ]
        appendShareSection(title: "New Accessible Apps", items: apps.map { "\($0.name) - \($0.url)" }, to: &lines)
        appendShareSection(title: "Podcast Episodes", items: podcasts.map { "\($0.title) - \($0.url)" }, to: &lines)
        appendShareSection(title: "Popular Discussions", items: forums.map { "\($0.title) - \($0.url)" }, to: &lines)
        appendShareSection(title: "Guides and Tutorials", items: resources.map { "\($0.title) - \($0.url)" }, to: &lines)
        appendShareSection(title: "Blog Posts", items: blogs.map { "\($0.title) - \($0.url)" }, to: &lines)
        return lines.joined(separator: "\n")
    }

    private static func countPart(_ count: Int, singular: String, plural: String) -> String? {
        guard count > 0 else { return nil }
        return "\(count) \(count == 1 ? singular : plural)"
    }

    private func appendShareSection(title: String, items: [String], to lines: inout [String]) {
        guard !items.isEmpty else { return }
        lines += ["", title]
        lines += items.map { "- \($0)" }
    }

    /// Derives a narrower-window view (e.g. "past 7 days") from this digest
    /// without a separate fetch — the fetch/cache always covers the widest
    /// window Mouse Recap offers, and every narrower window is just a
    /// client-side date filter over data already on hand. Each list stays in
    /// its already-sorted order, so this is a pure truncation, not a re-rank.
    ///
    /// One accepted tradeoff: `forums` was already capped to the top
    /// `mouseRecapForumLimit` topics for the WIDE window before this runs, so
    /// scoping down can only ever narrow that set further (or leave it
    /// unchanged) — it can't surface a topic that was popular specifically
    /// within the narrow window but didn't make the wide window's top slice.
    /// Simpler than re-fetching or re-ranking per window, and the cases it
    /// misses are edge cases, not the common path.
    func scoped(toLastDays days: Int) -> MouseRecapDigest {
        let newStart = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate.addingTimeInterval(-TimeInterval(days) * 24 * 60 * 60)
        guard newStart > startDate else { return self }
        return MouseRecapDigest(
            startDate: newStart,
            endDate: endDate,
            generatedAt: generatedAt,
            apps: apps.filter { $0.createdAt >= newStart },
            podcasts: podcasts.filter { $0.publishedAt >= newStart },
            forums: forums.filter { $0.lastActivityAt >= newStart },
            resources: resources.filter { $0.updatedAt >= newStart },
            blogs: blogs.filter { $0.publishedAt >= newStart || $0.lastActivityAt >= newStart }
        )
    }
}

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
    @Published private(set) var mouseRecap: MouseRecapDigest?
    @Published private(set) var isLoadingMouseRecap = false
    @Published private(set) var mouseRecapError: String?
    @Published private(set) var failedMouseRecapSourceNames: [String] = []
    /// Set only on a genuinely successful load — a failed attempt (e.g. no
    /// network) shouldn't count as "fresh" and block the next foreground
    /// retry within the staleness window. Backs HomeView's foreground
    /// auto-refresh (see its `.onChange(of: scenePhase)`).
    @Published private(set) var lastLoadedAt: Date?

    private let pageSize = 20
    private var page = 0
    private var itemVisits: [String: PersistenceStore.ItemVisit] = [:]
    private static let visitBoundaryKey = "applevis.home.visitBoundary"
    /// How long since the last successful load before a new one counts as
    /// "returning after being away" rather than "still in the same
    /// sitting" — matches HomeView's own foreground-refresh staleness
    /// window (`staleThreshold`), since both are answering the same
    /// underlying question with the same in-memory `lastLoadedAt`.
    private static let sittingGapThreshold: TimeInterval = 5 * 60
    /// The widest window Mouse Recap fetches and caches — every narrower
    /// window a user can select (see `MouseRecapWindow` in HomeView) is
    /// derived client-side from this same fetch via
    /// `MouseRecapDigest.scoped(toLastDays:)`, so there's only ever one
    /// fetch/cache to keep fresh regardless of which window is on screen.
    private static let mouseRecapMaxDays = 30
    // Scaled up from the old 7-day window's 8-page bound to keep roughly the
    // same per-day coverage headroom (8 * 30/7 ≈ 34, rounded down) rather
    // than leaving a 30-day recap capped at the same page count a week-long
    // one used.
    private static let mouseRecapMaxPages = 24
    private static let mouseRecapForumLimit = 5
    /// The boundary a never-individually-visited item is compared against
    /// — captured once per load() (see `advanceVisitBoundaryIfNeeded`) so
    /// it stays fixed for the whole current sitting rather than drifting
    /// with live wall-clock time, which would make content that was
    /// genuinely new when the sitting started flicker in and out of "New"
    /// as the clock ticks.
    private var currentVisitBoundary: Date = .distantPast

    func load() async {
        SoundPlayer.shared.play(.loadingStart)
        isLoading = true
        let hadNoItems = items.isEmpty
        if hadNoItems { error = nil }
        page = 0
        isReturningVisit = UserDefaults.standard.object(forKey: "applevis.lastVisit") != nil
        // Stamped exactly once, ever, purely to distinguish "first launch
        // of this install" (don't flood a brand-new user with everything
        // in the feed marked "new") from every launch after that.
        if !isReturningVisit {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "applevis.lastVisit")
        }

        let previousLoadedAt = lastLoadedAt
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
            items = Self.deduplicated(fetched.sorted { $0.lastActivityAt > $1.lastActivityAt })
            hasMore = fetched.count >= pageSize
            itemVisits = PersistenceStore.shared.allItemVisits()
            // Captured BEFORE potentially advancing it below, so this
            // sitting's own "is this genuinely new" comparisons use the
            // boundary as it stood at the start of the sitting, not one
            // that was just moved to "now."
            currentVisitBoundary = visitBoundary
            advanceVisitBoundaryIfNeeded(previousLoadedAt: previousLoadedAt)
            buildNewActivitySummary()
            lastLoadedAt = Date()
        }

        isLoading = false
    }

    private var visitBoundary: Date {
        let stored = UserDefaults.standard.double(forKey: Self.visitBoundaryKey)
        return stored > 0 ? Date(timeIntervalSince1970: stored) : .distantPast
    }

    /// Advances the boundary only when this load() represents a genuine new
    /// sitting — a cold launch (`previousLoadedAt` nil, since that's an
    /// in-memory property that resets every process launch), or returning
    /// after being away longer than `sittingGapThreshold` — never on a
    /// same-sitting refresh (pull-to-refresh, a filter change, Customize
    /// Home). An earlier version of this idea advanced on every load() and
    /// every background/foreground cycle, and silently dropped still-
    /// unread items out of "New" the moment the boundary moved past them —
    /// gating on a real gap is what avoids repeating that regression while
    /// still keeping stale backlog from counting as new. Reported directly:
    /// a fresh page of results was entirely "new" regardless of age, since
    /// nothing in it had an individual visit record yet to compare against.
    private func advanceVisitBoundaryIfNeeded(previousLoadedAt: Date?) {
        let isNewSitting = previousLoadedAt.map { Date().timeIntervalSince($0) > Self.sittingGapThreshold } ?? true
        guard isNewSitting else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.visitBoundaryKey)
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        page += 1
        let (more, _) = await fetchPage(page: page)
        let merged = (items + more).sorted { $0.lastActivityAt > $1.lastActivityAt }
        items = Self.deduplicated(merged)
        hasMore = more.count >= pageSize
    }

    /// Content posted between one page fetch and the next shifts every
    /// subsequent page by however many new items landed — the same
    /// forum topic/app/etc. already on screen from an earlier page can
    /// reappear on a later one. `ForEach(items)` keys rows by `FeedItem.id`,
    /// so two entries sharing an id is an actual SwiftUI identity
    /// collision, not just a visual duplicate — it was observed to pair a
    /// row with the wrong underlying item, tapping through to a stale/
    /// mismatched detail fetch that the server rejected outright (HTTP
    /// 400). Keeps the first (most-recently-sorted) occurrence of each id.
    private static func deduplicated(_ items: [FeedItem]) -> [FeedItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    /// New replies/comments on an item the user has visited before — distinct
    /// from an item being newer-than-lastVisit outright, since without this a
    /// long-running thread you'd already opened once could keep getting new
    /// replies forever without ever showing up in "New" again.
    func newReplyCount(for item: FeedItem) -> Int {
        guard let visit = itemVisits[item.id] else { return 0 }
        return max(0, item.commentCount - visit.commentCount)
    }

    /// Stamps this item as read (current comment count + now), so it drops
    /// out of "New" until it gets further activity. Matches the old app's
    /// per-item "Mark as Read" action — previously the only way for an item
    /// to leave the New view was for the global last-visit timestamp to
    /// advance past it, with no way to dismiss a single item on its own.
    func markAsRead(_ item: FeedItem) {
        PersistenceStore.shared.stampItemVisit(id: item.id, commentCount: item.commentCount)
        itemVisits[item.id] = PersistenceStore.ItemVisit(seenAt: Date(), commentCount: item.commentCount)
        if case .forumTopic(let topic) = item {
            PersistenceStore.shared.markTopicSeen(id: topic.id)
        }
        recomputeNewActivity()
        UIAccessibility.post(notification: .announcement, argument: "Marked as read.")
    }

    func markAllAsRead(_ itemsToMark: [FeedItem]) {
        guard !itemsToMark.isEmpty else { return }
        for item in itemsToMark {
            PersistenceStore.shared.stampItemVisit(id: item.id, commentCount: item.commentCount)
            itemVisits[item.id] = PersistenceStore.ItemVisit(seenAt: Date(), commentCount: item.commentCount)
            if case .forumTopic(let topic) = item {
                PersistenceStore.shared.markTopicSeen(id: topic.id)
            }
        }
        isNewActivityDismissed = true
        recomputeNewActivity()
        // Unlike single-item markAsRead above, this collapses several
        // sections at once — the What's New card, the New/Latest picker's
        // contents, and the whole New list emptying out — all in the same
        // pass as this announcement. Posting it immediately raced that
        // layout change and VoiceOver dropped it silently. A short delay
        // lets the collapse finish first. Reported directly: "Mark All
        // Read" said nothing.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            UIAccessibility.post(notification: .announcement, argument: "All new activity marked as read.")
        }
    }

    func loadMouseRecap(force: Bool = false) async {
        if !force, let mouseRecap, Date().timeIntervalSince(mouseRecap.generatedAt) < 10 * 60 {
            return
        }

        // Show last session's digest immediately instead of a blank loading
        // state — this is display-only, never a substitute for the API
        // check below, which always runs and overwrites it with whatever
        // Drupal currently reports (additions and removals both, since the
        // digest is rebuilt from scratch each time rather than patched).
        if mouseRecap == nil, let cached = PersistenceStore.shared.cachedMouseRecapDigest() {
            mouseRecap = cached
        }

        isLoadingMouseRecap = true
        mouseRecapError = nil
        failedMouseRecapSourceNames = []

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -Self.mouseRecapMaxDays, to: endDate) ?? endDate.addingTimeInterval(-TimeInterval(Self.mouseRecapMaxDays) * 24 * 60 * 60)
        let result = await fetchMouseRecapItems(since: startDate)

        failedMouseRecapSourceNames = result.failedSources
        if result.items.isEmpty && !result.failedSources.isEmpty {
            // Fetch failed outright — leave the cached digest (if any) on
            // screen rather than clearing it, same as Home's own failed-load
            // handling.
            mouseRecapError = "Couldn't load Mouse Recap. Pull to refresh."
        } else {
            let digest = Self.buildMouseRecap(from: result.items, startDate: startDate, endDate: endDate)
            mouseRecap = digest
            PersistenceStore.shared.saveMouseRecapDigest(digest)
        }

        isLoadingMouseRecap = false
    }

    // MARK: - Private

    private struct SourceFetchResult {
        let items: [FeedItem]
        let failedName: String?
    }

    private struct MouseRecapFetchResult {
        let items: [FeedItem]
        let failedSources: [String]
    }

    /// Runs one source's fetch in isolation so a single failing source
    /// (e.g. Forums down) can't wipe out the other four, which is what
    /// `try await (a, b, c, d, e)` on a tuple of `async let`s would do —
    /// the first throw propagates and every other result, even ones that
    /// already succeeded, gets discarded.
    private func fetchSource(name: String, _ fetch: @escaping @MainActor () async throws -> [FeedItem]) async -> SourceFetchResult {
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
                let filtered: [ForumTopic]
                if defaultFilter.supportsRefinement {
                    filtered = defaultFilter.apply(to: topics, lastVisit: PersistenceStore.shared.forumsLastVisit)
                } else {
                    filtered = topics
                }
                return filtered.map { FeedItem.forumTopic($0) }
              }
            : SourceFetchResult(items: [], failedName: nil)
        async let podcasts = showPodcasts
            ? fetchSource(name: "Podcasts") { try await APIClient.shared.podcasts.episodes(page: page).items.map { FeedItem.podcastEpisode($0) } }
            : SourceFetchResult(items: [], failedName: nil)
        async let apps = showApps
            ? fetchSource(name: "Apps") { try await APIClient.shared.apps.list(page: page).items.map { FeedItem.appListing($0) } }
            : SourceFetchResult(items: [], failedName: nil)
        async let guides = showGuides
            ? fetchSource(name: "Guides") { try await APIClient.shared.resources.list(page: page).items.map { FeedItem.resource($0) } }
            : SourceFetchResult(items: [], failedName: nil)
        async let blogs = showBlogs
            ? fetchSource(name: "Blogs") { try await APIClient.shared.blogs.list(page: page).items.map { FeedItem.blogPost($0) } }
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

    private func fetchMouseRecapItems(since startDate: Date) async -> MouseRecapFetchResult {
        let showForums   = UserDefaults.standard.object(forKey: "feed.showForums")   as? Bool ?? true
        let showPodcasts = UserDefaults.standard.object(forKey: "feed.showPodcasts") as? Bool ?? true
        let showApps     = UserDefaults.standard.object(forKey: "feed.showApps")     as? Bool ?? true
        let showGuides   = UserDefaults.standard.object(forKey: "feed.showGuides")   as? Bool ?? true
        let showBlogs    = UserDefaults.standard.object(forKey: "feed.showBlogs")    as? Bool ?? true
        let appleOnly    = UserDefaults.standard.object(forKey: "feed.appleOnly")    as? Bool ?? false

        async let forums = showForums
            ? fetchRecapPages(name: "Forums", since: startDate) { page in
                let topics = try await APIClient.shared.forums.recent(page: page, appleOnly: appleOnly)
                return (topics.map { FeedItem.forumTopic($0) }, topics.count >= APIPaging.pageSize)
            }
            : SourceFetchResult(items: [], failedName: nil)
        async let podcasts = showPodcasts
            ? fetchRecapPages(name: "Podcasts", since: startDate) { page in
                let result = try await APIClient.shared.podcasts.episodes(page: page)
                return (result.items.map { FeedItem.podcastEpisode($0) }, result.hasMore)
            }
            : SourceFetchResult(items: [], failedName: nil)
        async let apps = showApps
            ? fetchRecapPages(name: "Apps", since: startDate) { page in
                let result = try await APIClient.shared.apps.list(page: page)
                return (result.items.map { FeedItem.appListing($0) }, result.hasMore)
            }
            : SourceFetchResult(items: [], failedName: nil)
        async let guides = showGuides
            ? fetchRecapPages(name: "Guides", since: startDate) { page in
                let result = try await APIClient.shared.resources.list(page: page)
                return (result.items.map { FeedItem.resource($0) }, result.hasMore)
            }
            : SourceFetchResult(items: [], failedName: nil)
        async let blogs = showBlogs
            ? fetchRecapPages(name: "Blogs", since: startDate) { page in
                let result = try await APIClient.shared.blogs.list(page: page)
                return (result.items.map { FeedItem.blogPost($0) }, result.hasMore)
            }
            : SourceFetchResult(items: [], failedName: nil)

        let results = await [forums, podcasts, apps, guides, blogs]
        return MouseRecapFetchResult(
            items: Self.deduplicated(results.flatMap(\.items)),
            failedSources: results.compactMap(\.failedName)
        )
    }

    private func fetchRecapPages(
        name: String,
        since startDate: Date,
        fetch: @escaping @MainActor (_ page: Int) async throws -> (items: [FeedItem], hasMore: Bool)
    ) async -> SourceFetchResult {
        do {
            var allItems: [FeedItem] = []
            for page in 0..<Self.mouseRecapMaxPages {
                let result = try await fetch(page)
                let inRange = result.items.filter { $0.lastActivityAt >= startDate }
                allItems += inRange
                let reachedOlderItems = result.items.contains { $0.lastActivityAt < startDate }
                if !result.hasMore || reachedOlderItems { break }
            }
            return SourceFetchResult(items: allItems, failedName: nil)
        } catch {
            return SourceFetchResult(items: [], failedName: name)
        }
    }

    private static func buildMouseRecap(from items: [FeedItem], startDate: Date, endDate: Date) -> MouseRecapDigest {
        let apps = items.compactMap { item -> AppListing? in
            guard case .appListing(let app) = item,
                  app.createdAt >= startDate,
                  isStronglyAccessible(app)
            else { return nil }
            return app
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let podcasts = items.compactMap { item -> PodcastEpisode? in
            guard case .podcastEpisode(let episode) = item, episode.publishedAt >= startDate else { return nil }
            return episode
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let forums = items.compactMap { item -> ForumTopic? in
            guard case .forumTopic(let topic) = item, topic.lastActivityAt >= startDate else { return nil }
            return topic
        }
        .sorted {
            if $0.replyCount != $1.replyCount { return $0.replyCount > $1.replyCount }
            return $0.lastActivityAt > $1.lastActivityAt
        }
        .prefix(Self.mouseRecapForumLimit)

        let resources = items.compactMap { item -> Resource? in
            guard case .resource(let resource) = item, resource.updatedAt >= startDate else { return nil }
            return resource
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let blogs = items.compactMap { item -> BlogPost? in
            guard case .blogPost(let post) = item, post.publishedAt >= startDate || post.lastActivityAt >= startDate else { return nil }
            return post
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        return MouseRecapDigest(
            startDate: startDate,
            endDate: endDate,
            generatedAt: Date(),
            apps: apps,
            podcasts: podcasts,
            forums: Array(forums),
            resources: resources,
            blogs: blogs
        )
    }

    private static func isStronglyAccessible(_ app: AppListing) -> Bool {
        guard let rating = app.voiceOverPerformance?.lowercased(), !rating.isEmpty else { return false }
        return rating.contains("reads all page elements")
            || rating.contains("fully accessible")
            || rating.contains("completely accessible")
    }

    private func buildNewActivitySummary() {
        isNewActivityDismissed = false
        recomputeNewActivity()
    }

    /// An item counts as new if it has replies/comments (or any activity)
    /// beyond what it had the last time it *was* visited, or — for
    /// something never individually visited — if it was actually posted or
    /// updated since the current sitting started (`currentVisitBoundary`).
    /// That second half used to be unconditional ("never visited" alone was
    /// enough), which meant a full page of page-sized results was always
    /// entirely "new" regardless of actual age, since nothing in a freshly
    /// fetched page has a visit record yet. Suppressed entirely on a
    /// device's very first launch (isReturningVisit false) so a fresh
    /// install isn't flooded with everything in the feed marked new.
    private func isNewActivity(_ item: FeedItem) -> Bool {
        guard isReturningVisit else { return false }
        if newReplyCount(for: item) > 0 { return true }
        guard let visit = itemVisits[item.id] else {
            return item.lastActivityAt > currentVisitBoundary
        }
        return visit.seenAt < item.lastActivityAt
    }

    private func recomputeNewActivity() {
        guard PersistenceStore.shared.isReadHistoryTrackingEnabled else {
            newItems = []
            newActivitySummary = ""
            HomeBadgeStore.shared.unreadForumTopicCount = 0
            return
        }
        newItems = items.filter(isNewActivity)
        HomeBadgeStore.shared.unreadForumTopicCount = newItems.filter {
            if case .forumTopic = $0 { return true }
            return false
        }.count
        guard !newItems.isEmpty else { newActivitySummary = ""; return }
        newActivitySummary = Self.buildSummaryText(for: newItems, itemVisits: itemVisits)
    }

    /// Breaks "N new items" down by what actually changed — e.g. "2 new
    /// forum topics, 1 new podcast episode, 5 new comments" — instead of a
    /// bare count that doesn't say what kind of activity it was.
    ///
    /// The comment figure counts: the reply delta for items you'd already
    /// visited before (only the new part, since you've seen the rest), plus
    /// the FULL comment count for brand-new items (since you've never seen
    /// any of it). Without that second half, a user who mostly just
    /// refreshes Home without opening individual items would never see a
    /// "new comments" figure at all — every item would be brand-new (no
    /// prior visit to diff against), so the count stayed permanently 0
    /// even when those brand-new topics already had real replies attached.
    private static func buildSummaryText(for newItems: [FeedItem], itemVisits: [String: PersistenceStore.ItemVisit]) -> String {
        var brandNewByKind: [ContentKind: Int] = [:]
        var newCommentTotal = 0
        for item in newItems {
            if let visit = itemVisits[item.id] {
                newCommentTotal += max(0, item.commentCount - visit.commentCount)
            } else {
                brandNewByKind[item.kind, default: 0] += 1
                newCommentTotal += item.commentCount
            }
        }
        var parts: [String] = []
        for kind in [ContentKind.forumTopic, .podcastEpisode, .appListing, .resource, .blogPost] {
            guard let n = brandNewByKind[kind], n > 0 else { continue }
            parts.append("\(n) new \(kind.displayNamePlural(n))")
        }
        if newCommentTotal > 0 {
            parts.append("\(newCommentTotal) new comment\(newCommentTotal == 1 ? "" : "s")")
        }
        guard !parts.isEmpty else {
            return "\(newItems.count) new item\(newItems.count == 1 ? "" : "s") since your last visit"
        }
        return parts.joined(separator: ", ") + " since your last visit"
    }
}
