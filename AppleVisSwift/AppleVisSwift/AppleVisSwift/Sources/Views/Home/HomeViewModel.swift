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
    /// Set only on a genuinely successful load — a failed attempt (e.g. no
    /// network) shouldn't count as "fresh" and block the next foreground
    /// retry within the staleness window. Backs HomeView's foreground
    /// auto-refresh (see its `.onChange(of: scenePhase)`).
    @Published private(set) var lastLoadedAt: Date?

    private let pageSize = 20
    private var page = 0
    private var itemVisits: [String: PersistenceStore.ItemVisit] = [:]

    func load() async {
        SoundPlayer.shared.play(.loadingStart)
        isLoading = true
        let hadNoItems = items.isEmpty
        if hadNoItems { error = nil }
        page = 0
        isReturningVisit = UserDefaults.standard.object(forKey: "applevis.lastVisit") != nil
        // Stamped exactly once, ever, purely to distinguish "first launch
        // of this install" (don't flood a brand-new user with everything
        // in the feed marked "new") from every launch after that. Earlier
        // attempts tried to use this as a moving "last visit" boundary that
        // advanced on every load(), then on every background/foreground
        // cycle — both silently dropped still-unread items out of "New"
        // the moment the boundary moved past them (a screen simply locking
        // counts as backgrounding). isNewActivity() below no longer
        // compares against a timestamp at all — an item stays "new" for as
        // long as it's genuinely unvisited, full stop, which is what
        // "shows all 11 until they're read" actually requires.
        if !isReturningVisit {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "applevis.lastVisit")
        }

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
            buildNewActivitySummary()
            lastLoadedAt = Date()
        }

        isLoading = false
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
        UIAccessibility.post(notification: .announcement, argument: "All new activity marked as read.")
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
                let filtered = defaultFilter.supportsRefinement
                    ? defaultFilter.apply(to: topics, lastVisit: await PersistenceStore.shared.forumsLastVisit)
                    : topics
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

    private func buildNewActivitySummary() {
        isNewActivityDismissed = false
        recomputeNewActivity()
    }

    /// An item counts as new if it's never been individually visited, or it
    /// has replies/comments (or any activity) beyond what it had the last
    /// time it *was* visited — purely per-item, no global "last visit"
    /// timestamp involved. It stays "new" across any number of refreshes,
    /// backgrounds, or relaunches until the user actually opens it or hits
    /// "Mark All Read" — that's the only thing that should make an unread
    /// item stop being new. Suppressed entirely on a device's very first
    /// launch (isReturningVisit false) so a fresh install isn't flooded
    /// with everything in the feed marked new.
    private func isNewActivity(_ item: FeedItem) -> Bool {
        guard isReturningVisit else { return false }
        if newReplyCount(for: item) > 0 { return true }
        guard let visit = itemVisits[item.id] else { return true }
        return visit.seenAt < item.lastActivityAt
    }

    private func recomputeNewActivity() {
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
