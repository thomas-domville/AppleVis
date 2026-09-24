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
    let forumExcerpts: [String: String]

    init(
        startDate: Date,
        endDate: Date,
        generatedAt: Date,
        apps: [AppListing],
        podcasts: [PodcastEpisode],
        forums: [ForumTopic],
        resources: [Resource],
        blogs: [BlogPost],
        forumExcerpts: [String: String] = [:]
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.generatedAt = generatedAt
        self.apps = apps
        self.podcasts = podcasts
        self.forums = forums
        self.resources = resources
        self.blogs = blogs
        self.forumExcerpts = forumExcerpts
    }

    private enum CodingKeys: String, CodingKey {
        case startDate, endDate, generatedAt, apps, podcasts, forums, resources, blogs, forumExcerpts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        apps = try container.decode([AppListing].self, forKey: .apps)
        podcasts = try container.decode([PodcastEpisode].self, forKey: .podcasts)
        forums = try container.decode([ForumTopic].self, forKey: .forums)
        resources = try container.decode([Resource].self, forKey: .resources)
        blogs = try container.decode([BlogPost].self, forKey: .blogs)
        forumExcerpts = try container.decodeIfPresent([String: String].self, forKey: .forumExcerpts) ?? [:]
    }

    var isEmpty: Bool {
        apps.isEmpty && podcasts.isEmpty && forums.isEmpty && resources.isEmpty && blogs.isEmpty
    }

    var appPickSpotlight: BlogPost? {
        blogs.first(where: { Self.isAppPickSpotlight($0) })
    }

    var standardBlogs: [BlogPost] {
        blogs.filter { !Self.isAppPickSpotlight($0) }
    }

    /// One entry per non-empty section, each a whole translatable phrase with
    /// real plural forms — the old version glued an English noun onto the
    /// count ("3 " + "podcast episodes"), which no other language could follow.
    private var countParts: [String] {
        [
            apps.isEmpty ? nil : String(localized: "\(apps.count) accessible apps"),
            podcasts.isEmpty ? nil : String(localized: "\(podcasts.count) podcast episodes"),
            forums.isEmpty ? nil : String(localized: "\(forums.count) popular discussions"),
            resources.isEmpty ? nil : String(localized: "\(resources.count) guides and tutorials"),
            blogs.isEmpty ? nil : String(localized: "\(blogs.count) blog posts"),
        ].compactMap { $0 }
    }

    var countSummary: String {
        let parts = countParts
        return parts.isEmpty ? String(localized: "No recap items found for this period.") : parts.joined(separator: " · ")
    }

    var dateRangeText: String {
        let start = startDate.formatted(date: .abbreviated, time: .omitted)
        let end = endDate.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "\(start) through \(end)")
    }

    func newsletterIntro(for periodName: String) -> String {
        let period = periodName.lowercased()
        let parts = countParts

        guard !parts.isEmpty else {
            return String(localized: "No recap items were found for the \(period).")
        }

        let list = ListFormatter.localizedString(byJoining: parts)
        return String(localized: "Here's your AppleVis roundup from the \(period). \(editorialLead) Inside: \(list).")
    }

    func shareText(for periodName: String, aiBlurbs: [String: String] = [:]) -> String {
        let limits = Self.limits(for: periodName)
        let visibleApps = Array(apps.prefix(limits.apps))
        let visiblePodcasts = Array(podcasts.prefix(limits.podcasts))
        let visibleBlogs = Array(standardBlogs.prefix(limits.blogs))
        let visibleResources = Array(resources.prefix(limits.resources))
        let visibleForums = Array(forums.prefix(limits.forums))

        var lines = [
            String(localized: "Mouse Recap"),
            periodName,
            dateRangeText,
            "",
            String(localized: "From the Mouse"),
            newsletterIntro(for: periodName),
        ]

        if let spotlight = appPickSpotlight {
            appendShareSection(
                title: String(localized: "Spotlight Feature"),
                description: String(localized: "AnonyMouse's App Pick of the Month"),
                items: [shareItem(
                    title: spotlight.title,
                    details: blogDetails(spotlight),
                    body: aiBlurbs[spotlight.id] ?? newsletterBody(for: spotlight),
                    url: spotlight.url
                )],
                to: &lines
            )
        }

        appendShareSection(
            title: String(localized: "In This Recap"),
            description: "",
            items: tableOfContents(periodName: periodName).map { "\($0.title): \($0.detail)" },
            to: &lines
        )

        appendShareSection(
            title: String(localized: "New Accessible Apps"),
            description: appSectionIntro(periodName: periodName),
            items: visibleApps.map {
                shareItem(title: $0.name, details: appDetails($0), body: aiBlurbs[$0.id] ?? newsletterBody(for: $0), url: $0.url)
            },
            to: &lines
        )
        appendShareSection(
            title: podcastSectionTitle(periodName: periodName),
            description: podcastSectionIntro(periodName: periodName),
            items: visiblePodcasts.map {
                shareItem(title: $0.title, details: podcastDetails($0), body: aiBlurbs[$0.id] ?? newsletterBody(for: $0), url: $0.url)
            },
            to: &lines
        )
        appendShareSection(
            title: String(localized: "From the AppleVis Blog"),
            description: blogSectionIntro(periodName: periodName),
            items: visibleBlogs.map {
                shareItem(title: $0.title, details: blogDetails($0), body: aiBlurbs[$0.id] ?? newsletterBody(for: $0), url: $0.url)
            },
            to: &lines
        )
        appendShareSection(
            title: String(localized: "How-To Corner"),
            description: resourceSectionIntro(periodName: periodName),
            items: visibleResources.map {
                shareItem(title: $0.title, details: resourceDetails($0), body: aiBlurbs[$0.id] ?? newsletterBody(for: $0), url: $0.url)
            },
            to: &lines
        )
        appendShareSection(
            title: String(localized: "Community Voices"),
            description: forumSectionIntro(periodName: periodName),
            items: visibleForums.map {
                shareItem(title: $0.title, details: forumDetails($0), body: aiBlurbs[$0.id] ?? newsletterBody(for: $0), url: $0.url)
            },
            to: &lines
        )
        return lines.joined(separator: "\n")
    }

    func tableOfContents(periodName: String) -> [(title: String, detail: String)] {
        var items: [(String, String)] = []
        if appPickSpotlight != nil { items.append((String(localized: "Spotlight Feature"), String(localized: "AnonyMouse's App Pick of the Month"))) }
        if !apps.isEmpty { items.append((String(localized: "New Accessible Apps"), String(localized: "\(apps.count) apps"))) }
        if !podcasts.isEmpty { items.append((podcastSectionTitle(periodName: periodName), String(localized: "\(podcasts.count) episodes"))) }
        if !standardBlogs.isEmpty { items.append((String(localized: "From the AppleVis Blog"), String(localized: "\(standardBlogs.count) posts"))) }
        if !resources.isEmpty { items.append((String(localized: "How-To Corner"), String(localized: "\(resources.count) guides and tutorials"))) }
        if !forums.isEmpty { items.append((String(localized: "Community Voices"), String(localized: "\(forums.count) discussions"))) }
        return items
    }

    func newsletterBody(for app: AppListing) -> String {
        let fallback = String(localized: "\(app.name) is a \(app.platform.displayName) app in \(app.category).")
        return excerpt(from: app.summary, fallback: fallback)
    }

    func newsletterBody(for episode: PodcastEpisode) -> String {
        excerpt(from: episode.description, fallback: String(localized: "Listen to the full episode on AppleVis."))
    }

    func newsletterBody(for resource: Resource) -> String {
        excerpt(from: resource.summary, fallback: String(localized: "Read more on AppleVis."))
    }

    func newsletterBody(for post: BlogPost) -> String {
        excerpt(from: post.summary, fallback: String(localized: "Read the full post on AppleVis."))
    }

    func newsletterBody(for topic: ForumTopic) -> String {
        if let excerpt = forumExcerpts[topic.id], !excerpt.isEmpty {
            return excerpt
        }
        let comments = String(localized: "\(topic.replyCount) comments")
        if topic.category.isEmpty {
            return String(localized: "This discussion has been active in the community, with \(comments) so far.")
        }
        return String(localized: "This \(topic.category) discussion has been active in the community, with \(comments) so far.")
    }

    func appDetails(_ app: AppListing) -> [String] {
        [
            app.developer.isEmpty ? "" : String(localized: "Developer: \(app.developer)"),
            String(localized: "Platform: \(app.platform.displayName)"),
            app.category.isEmpty ? "" : String(localized: "Category: \(app.category)"),
            app.price.isEmpty ? "" : String(localized: "Price: \(app.price)"),
        ].filter { !$0.isEmpty }
    }

    func podcastDetails(_ episode: PodcastEpisode) -> [String] {
        [
            episode.showTitle,
            episode.authorName.isEmpty ? "" : String(localized: "By \(episode.authorName)"),
            publishedText(episode.publishedAt),
        ].filter { !$0.isEmpty }
    }

    func blogDetails(_ post: BlogPost) -> [String] {
        [
            post.authorName.isEmpty ? "" : String(localized: "By \(post.authorName)"),
            publishedText(post.publishedAt),
            String(localized: "\(post.commentCount) comments"),
        ].filter { !$0.isEmpty }
    }

    func resourceDetails(_ resource: Resource) -> [String] {
        [
            resource.kind.displayName,
            resource.authorName.isEmpty ? "" : String(localized: "By \(resource.authorName)"),
            publishedText(resource.createdAt),
            String(localized: "\(resource.commentCount) comments"),
        ].filter { !$0.isEmpty }
    }

    func forumDetails(_ topic: ForumTopic) -> [String] {
        let active = topic.lastActivityAt.formatted(.relative(presentation: .named))
        return [
            topic.category.isEmpty ? "" : topic.category,
            topic.authorName.isEmpty ? "" : String(localized: "By \(topic.authorName)"),
            String(localized: "\(topic.replyCount) comments"),
            String(localized: "Active \(active)"),
        ].filter { !$0.isEmpty }
    }

    func appSectionIntro(periodName: String) -> String {
        String(localized: "A fresh batch of App Directory entries arrived in the \(periodName.lowercased()), with practical discoveries for blind and low vision Apple users.")
    }

    /// `periodName` is the window's translated label, so compare it with the
    /// translated "Past Month" rather than searching it for the English word
    /// "month", which never matched in other languages.
    static func isMonth(_ periodName: String) -> Bool {
        periodName == MouseRecapWindow.month.label
    }

    func podcastSectionTitle(periodName: String) -> String {
        Self.isMonth(periodName)
            ? String(localized: "This Month in Podcasts")
            : String(localized: "This Week in Podcasts")
    }

    func podcastSectionIntro(periodName: String) -> String {
        String(localized: "Recent AppleVis audio brought walkthroughs, conversations, and tips worth catching.")
    }

    func blogSectionIntro(periodName: String) -> String {
        String(localized: "News, updates, and editorial perspective from the AppleVis Blog.")
    }

    func resourceSectionIntro(periodName: String) -> String {
        String(localized: "Hands-on help and explainers for making more of your Apple devices.")
    }

    func forumSectionIntro(periodName: String) -> String {
        String(localized: "A curated look at active community conversations from the \(periodName.lowercased()).")
    }

    static func limits(for periodName: String) -> (apps: Int, podcasts: Int, blogs: Int, resources: Int, forums: Int) {
        if isMonth(periodName) {
            return (apps: 12, podcasts: 5, blogs: 5, resources: 6, forums: 8)
        }
        return (apps: 8, podcasts: 5, blogs: 5, resources: 6, forums: 5)
    }

    static func isAppPickSpotlight(_ post: BlogPost) -> Bool {
        let title = post.title.lowercased()
        let url = post.url.lowercased()
        return (title.contains("anonymous") && title.contains("app pick") && title.contains("month"))
            || url.contains("anonymouses-app-pick-month")
            || url.contains("anonymous-app-pick-month")
    }

    func excerpt(from text: String, fallback: String, maxLength: Int = 420) -> String {
        let plain = HTMLText.plainText(fromHTML: text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plain.isEmpty else { return fallback }
        guard plain.count > maxLength else { return plain }
        let cutoff = plain.index(plain.startIndex, offsetBy: maxLength)
        let prefix = plain[..<cutoff]
        if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
            let sentence = plain.index(after: sentenceEnd)
            let trimmed = String(plain[..<sentence]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "\(String(prefix).trimmingCharacters(in: .whitespacesAndNewlines))..."
    }

    private func publishedText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var editorialLead: String {
        if !apps.isEmpty && !forums.isEmpty {
            return String(localized: "New app discoveries and community conversations led the way.")
        }
        if !apps.isEmpty {
            return String(localized: "New app discoveries led the way.")
        }
        if !forums.isEmpty {
            return String(localized: "Community conversations led the way.")
        }
        if !podcasts.isEmpty {
            return String(localized: "Recent podcast episodes brought fresh walkthroughs and tips.")
        }
        if !resources.isEmpty {
            return String(localized: "Fresh guides and tutorials brought practical help.")
        }
        if !blogs.isEmpty {
            return String(localized: "AppleVis blog posts brought the latest news and perspective.")
        }
        return String(localized: "Check back soon for new apps, podcasts, discussions, guides, and blog posts.")
    }

    private func appendShareSection(title: String, description: String, items: [String], to lines: inout [String]) {
        guard !items.isEmpty else { return }
        lines += ["", title]
        if !description.isEmpty { lines.append(description) }
        lines += items
    }

    private func shareItem(title: String, details: [String], body: String, url: String) -> String {
        var lines = [title]
        if !details.isEmpty { lines += details }
        lines += ["", body, "", String(localized: "Read on AppleVis:"), url]
        return lines.joined(separator: "\n")
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
            resources: resources.filter { $0.createdAt >= newStart },
            blogs: blogs.filter { $0.publishedAt >= newStart || $0.lastActivityAt >= newStart },
            forumExcerpts: forumExcerpts
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

    /// The single most recently visited item, if it's still present in the
    /// currently loaded feed — drives "pick up where you left off" Home
    /// focus (HomeView.announceWelcomeIfNeeded) when there's no new activity
    /// to summarize instead. Requested directly.
    var lastVisitedItemId: String? {
        guard let mostRecent = itemVisits.max(by: { $0.value.seenAt < $1.value.seenAt }) else { return nil }
        return items.contains(where: { $0.id == mostRecent.key }) ? mostRecent.key : nil
    }

    private let pageSize = 20
    private var page = 0
    private var itemVisits: [String: PersistenceStore.ItemVisit] = [:]
    /// Comment counts for never-opened items, captured when each first
    /// appeared — see `establishFeedBaselines` and PersistenceStore's
    /// "Feed baselines" section.
    private var feedBaselines: [String: PersistenceStore.FeedBaseline] = [:]
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
    private static let mouseRecapAppLimit = 12
    private static let mouseRecapPodcastLimit = 5
    private static let mouseRecapBlogLimit = 6
    private static let mouseRecapResourceLimit = 6
    private static let mouseRecapForumLimit = 8
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
        // Home's forum topic cards bake their bell-badge state in at mapping
        // time (`Mappers.forum`/`forumFromRecent`), unlike Following/
        // Recommended's own tabs which check a store live — so unless this
        // finishes before `fetchPage` maps the forums source below, a topic
        // followed on the website (or a second device) would still show a
        // plain, un-badged card here on this device's first load after
        // sign-in. A cheap no-op every load after the first. Requested
        // directly, as the Home-tab half of the same website-sync gap
        // Recommend's button state never had.
        if let user = AuthStore.current?.user {
            await FollowStore.shared.loadIfNeeded(for: user)
        }
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
                error = String(localized: "Couldn't load Home. Pull to refresh.")
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
            await establishFeedBaselines(for: items)
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
        // Later pages need baselines too, or an unopened item that only
        // ever appears past page one could never show a count.
        await establishFeedBaselines(for: more)
        recomputeNewActivity()
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
    ///
    /// Falls back to the item's feed baseline when it's never been opened,
    /// so unopened items get the same kind of count opened ones always had.
    func newReplyCount(for item: FeedItem) -> Int {
        guard let seenCount = itemVisits[item.id]?.commentCount ?? feedBaselines[item.id]?.commentCount else { return 0 }
        return max(0, item.commentCount - seenCount)
    }

    /// Posted since the last visit and not yet opened or marked read — gets
    /// the "NEW" badge (alongside a comment count, if it has comments),
    /// and counts as a new topic/episode/etc. in the summary. Stays true
    /// until cleared, not just until the visit boundary next moves.
    func isBrandNew(_ item: FeedItem) -> Bool {
        itemVisits[item.id] == nil && feedBaselines[item.id]?.isNewItem == true
    }

    /// Records a comment-count baseline for every item that has neither a
    /// visit nor a baseline yet — set once, at first sight, never moved
    /// forward, so an unopened item's "N new" keeps building until it's
    /// opened or marked read:
    /// - first launch, or no activity since the visit boundary: its
    ///   current count (nothing new).
    /// - posted since the boundary: 0, and flagged brand new — none of it
    ///   has been seen, so every comment counts.
    /// - older, but with activity since the boundary: asks the server
    ///   exactly how many comments arrived since then (one small query per
    ///   item, only ever on first sight). If that fails, assumes 1 — the
    ///   activity timestamp proves at least something happened.
    private func establishFeedBaselines(for items: [FeedItem]) async {
        feedBaselines = PersistenceStore.shared.allFeedBaselines()
        let boundary = currentVisitBoundary
        let hasBoundary = isReturningVisit && boundary != .distantPast
        let now = Date()
        var additions: [String: PersistenceStore.FeedBaseline] = [:]
        var needsExactCount: [FeedItem] = []

        for item in items where itemVisits[item.id] == nil && feedBaselines[item.id] == nil && additions[item.id] == nil {
            if !hasBoundary || item.lastActivityAt <= boundary {
                additions[item.id] = .init(firstSeenAt: now, commentCount: item.commentCount, isNewItem: false)
            } else if item.createdAt > boundary {
                additions[item.id] = .init(firstSeenAt: now, commentCount: 0, isNewItem: true)
            } else {
                needsExactCount.append(item)
            }
        }

        let newSince = await Self.commentCountsSince(boundary, for: needsExactCount)
        for item in needsExactCount {
            let arrived = newSince[item.id] ?? 1
            additions[item.id] = .init(firstSeenAt: now, commentCount: max(0, item.commentCount - arrived), isNewItem: false)
        }

        PersistenceStore.shared.addFeedBaselines(additions)
        feedBaselines = PersistenceStore.shared.allFeedBaselines()
    }

    /// How many comments each item received after `date`, keyed by
    /// `FeedItem.id`. Items whose query fails are left out. Four at a time,
    /// matching the app's other bounded fan-outs.
    private static func commentCountsSince(_ date: Date, for items: [FeedItem]) async -> [String: Int] {
        guard !items.isEmpty else { return [:] }
        // Plain strings only, so nothing main-actor-isolated crosses into
        // the child tasks.
        let requests = items.map { (id: $0.id, bundle: $0.commentBundle.rawValue, contentId: $0.contentId) }
        var results: [String: Int] = [:]
        await withTaskGroup(of: (String, Int?).self) { group in
            var iterator = requests.makeIterator()
            for _ in 0..<4 {
                guard let r = iterator.next() else { break }
                group.addTask { (r.id, try? await commentCountSince(date, bundle: r.bundle, contentId: r.contentId)) }
            }
            while let (id, count) = await group.next() {
                if let count { results[id] = count }
                if let r = iterator.next() {
                    group.addTask { (r.id, try? await commentCountSince(date, bundle: r.bundle, contentId: r.contentId)) }
                }
            }
        }
        return results
    }

    /// Drupal's JSON:API only honors a `created` filter given as a Unix
    /// timestamp — an ISO date string is silently ignored and returns every
    /// comment (confirmed live, 2026-09-23).
    private static func commentCountSince(_ date: Date, bundle: String, contentId: String) async throws -> Int {
        var total = 0
        for page in 0..<10 {
            let response = try await APIClient.shared.jsonAPIList(
                "comment/\(bundle)",
                query: [
                    "filter[entity_id.id]": contentId,
                    "filter[since][condition][path]": "created",
                    "filter[since][condition][operator]": ">",
                    "filter[since][condition][value]": "\(Int(date.timeIntervalSince1970))",
                    "fields[comment--\(bundle)]": "created",
                    "page[limit]": "50",
                    "page[offset]": "\(page * 50)",
                ]
            )
            total += response.data.count
            if response.data.count < 50 { break }
        }
        return total
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
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Marked as read."))
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
            mouseRecapError = String(localized: "Couldn't load Mouse Recap. Pull to refresh.")
        } else {
            let digest = await enrichMouseRecap(Self.buildMouseRecap(from: result.items, startDate: startDate, endDate: endDate))
            mouseRecap = digest
            PersistenceStore.shared.saveMouseRecapDigest(digest)
        }

        isLoadingMouseRecap = false
    }

    private func enrichMouseRecap(_ digest: MouseRecapDigest) async -> MouseRecapDigest {
        guard !digest.forums.isEmpty else { return digest }
        var excerpts = digest.forumExcerpts

        for topic in digest.forums.prefix(Self.mouseRecapForumLimit) where excerpts[topic.id] == nil {
            guard let detail = try? await APIClient.shared.forums.topicDetail(id: topic.id) else { continue }
            let excerpt = digest.excerpt(from: detail.body, fallback: "", maxLength: 420)
            if !excerpt.isEmpty {
                excerpts[topic.id] = excerpt
            }
        }

        return MouseRecapDigest(
            startDate: digest.startDate,
            endDate: digest.endDate,
            generatedAt: digest.generatedAt,
            apps: digest.apps,
            podcasts: digest.podcasts,
            forums: digest.forums,
            resources: digest.resources,
            blogs: digest.blogs,
            forumExcerpts: excerpts
        )
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

        async let forums = showForums
            ? fetchSource(name: "Forums") {
                // No separate forum-only pre-filter here anymore — Home's
                // own All/New/Mouse Recap switcher is the one place any
                // content type gets filtered, forums included. A hidden
                // Settings > Home Feed picker used to narrow forum topics
                // before that switcher ever saw them, so choosing "All"
                // could still silently show only, say, Unread topics with
                // no visible explanation why. Removed. Requested directly.
                let topics = try await APIClient.shared.forums.recent(page: page, appleOnly: appleOnly)
                return topics.map { FeedItem.forumTopic($0) }
              }
            : SourceFetchResult(items: [], failedName: nil)
        // Page 0 of each of these also pulls in whatever just got comments —
        // see `recentlyCommented`.
        let includeRecentlyCommented = page == 0
        async let podcasts = showPodcasts
            ? fetchSource(name: "Podcasts") {
                async let listedPage = APIClient.shared.podcasts.episodes(page: page)
                async let active = Self.recentlyCommented(
                    enabled: includeRecentlyCommented,
                    bundle: "comment_node_podcast", nodeType: "podcast",
                    include: "entity_id,entity_id.uid,entity_id.field_podcast,entity_id.taxonomy_vocabulary_15",
                    map: { FeedItem.podcastEpisode(Mappers.podcast($0, included: $1)) }
                )
                let listed = try await listedPage.items.map { FeedItem.podcastEpisode($0) }
                return Self.adding(await active, to: listed)
              }
            : SourceFetchResult(items: [], failedName: nil)
        async let apps = showApps
            ? fetchSource(name: "Apps") {
                async let listedPage = APIClient.shared.apps.list(page: page)
                async let active = Self.recentlyCommented(
                    enabled: includeRecentlyCommented,
                    bundle: "comment_node_ios_app_directory", nodeType: "ios_app_directory",
                    include: "entity_id,entity_id.uid",
                    map: { FeedItem.appListing(Mappers.app($0, included: $1)) }
                )
                let listed = try await listedPage.items.map { FeedItem.appListing($0) }
                return Self.adding(await active, to: listed)
              }
            : SourceFetchResult(items: [], failedName: nil)
        async let guides = showGuides
            ? fetchSource(name: "Guides") {
                async let listedPage = APIClient.shared.resources.list(page: page)
                async let active = Self.recentlyCommented(
                    enabled: includeRecentlyCommented,
                    bundle: "comment_node_guides", nodeType: "guides",
                    include: "entity_id,entity_id.uid,entity_id.taxonomy_vocabulary_3",
                    map: { FeedItem.resource(Mappers.resource($0, included: $1)) }
                )
                let listed = try await listedPage.items.map { FeedItem.resource($0) }
                return Self.adding(await active, to: listed)
              }
            : SourceFetchResult(items: [], failedName: nil)
        async let blogs = showBlogs
            ? fetchSource(name: "Blogs") {
                async let listedPage = APIClient.shared.blogs.list(page: page)
                async let active = Self.recentlyCommented(
                    enabled: includeRecentlyCommented,
                    bundle: "comment_node_blog2", nodeType: "blog2",
                    include: "entity_id,entity_id.uid",
                    map: { FeedItem.blogPost(Mappers.blog($0, included: $1)) }
                )
                let listed = try await listedPage.items.map { FeedItem.blogPost($0) }
                return Self.adding(await active, to: listed)
              }
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

    /// Posts, episodes, guides, and app entries that just got comments.
    /// Their list endpoints can only sort by when the item itself was last
    /// edited (JSON:API rejects sorting on the comment-statistics field —
    /// "Invalid specifier 'last_comment_timestamp'", confirmed live
    /// 2026-09-23), so an older item getting a burst of comments never
    /// reached page 0 and couldn't show up as new on Home. Beta-tester
    /// report: an iPhone 18 Pro blog post with comments that day didn't
    /// appear. This asks for the newest 50 comments across the whole
    /// bundle instead and keeps the items they belong to — one extra
    /// request per type, with each item's author (and, for episodes, its
    /// audio file) included so it maps exactly like a list result. Same
    /// technique GuidelineViolationScanner uses. Failures just return
    /// nothing: the regular list still loads either way.
    private static func recentlyCommented(
        enabled: Bool,
        bundle: String,
        nodeType: String,
        include: String,
        map: @MainActor (JsonApiNode, [JsonApiNode]) -> FeedItem
    ) async -> [FeedItem] {
        guard enabled else { return [] }
        guard let response = try? await APIClient.shared.jsonAPIList(
            "comment/\(bundle)",
            query: [
                "sort": "-created",
                "page[limit]": "50",
                "fields[comment--\(bundle)]": "created,entity_id",
                "include": include,
            ]
        ) else { return [] }
        let included = response.included ?? []
        var seen = Set<String>()
        return included
            .filter { $0.type == "node--\(nodeType)" && seen.insert($0.id).inserted }
            .map { map($0, included) }
    }

    /// Appends the recently-commented items the regular list didn't
    /// already have — the list's own copy wins when both have one.
    private static func adding(_ extra: [FeedItem], to listed: [FeedItem]) -> [FeedItem] {
        let listedIds = Set(listed.map(\.id))
        return listed + extra.filter { !listedIds.contains($0.id) }
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
        .prefix(Self.mouseRecapAppLimit)

        let podcasts = items.compactMap { item -> PodcastEpisode? in
            guard case .podcastEpisode(let episode) = item, episode.publishedAt >= startDate else { return nil }
            return episode
        }
        .sorted { $0.publishedAt > $1.publishedAt }
        .prefix(Self.mouseRecapPodcastLimit)

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
            guard case .resource(let resource) = item, resource.createdAt >= startDate else { return nil }
            return resource
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(Self.mouseRecapResourceLimit)

        let blogs = items.compactMap { item -> BlogPost? in
            guard case .blogPost(let post) = item, post.publishedAt >= startDate || post.lastActivityAt >= startDate else { return nil }
            return post
        }
        .sorted {
            if MouseRecapDigest.isAppPickSpotlight($0) != MouseRecapDigest.isAppPickSpotlight($1) {
                return MouseRecapDigest.isAppPickSpotlight($0)
            }
            return $0.publishedAt > $1.publishedAt
        }
        .prefix(Self.mouseRecapBlogLimit)

        return MouseRecapDigest(
            startDate: startDate,
            endDate: endDate,
            generatedAt: Date(),
            apps: Array(apps),
            podcasts: Array(podcasts),
            forums: Array(forums),
            resources: Array(resources),
            blogs: Array(blogs)
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
        if let visit = itemVisits[item.id] {
            return visit.seenAt < item.lastActivityAt
        }
        if let baseline = feedBaselines[item.id] {
            return baseline.isNewItem
        }
        return item.lastActivityAt > currentVisitBoundary
    }

    private func recomputeNewActivity() {
        guard PersistenceStore.shared.showsNewActivityIndicators else {
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
        newActivitySummary = buildSummaryText(for: newItems)
    }

    /// Breaks "N new items" down by what actually changed — e.g. "2 new
    /// forum topics, 1 new podcast episode, 5 new comments" — instead of a
    /// bare count that doesn't say what kind of activity it was.
    ///
    /// The comment figure is the same per-item count each card shows
    /// (`newReplyCount`) — since your last open for opened items, since
    /// first sight for unopened ones, and all of them for something posted
    /// since your last visit (its baseline is 0). Only items actually
    /// posted since the last visit count as "new topics" etc. — this used
    /// to count every never-opened item that way, so a months-old thread
    /// with one fresh comment was reported as a new topic.
    private func buildSummaryText(for newItems: [FeedItem]) -> String {
        var brandNewByKind: [ContentKind: Int] = [:]
        var newCommentTotal = 0
        for item in newItems {
            if isBrandNew(item) {
                brandNewByKind[item.kind, default: 0] += 1
            }
            newCommentTotal += newReplyCount(for: item)
        }
        var parts: [String] = []
        for kind in [ContentKind.forumTopic, .podcastEpisode, .appListing, .resource, .blogPost] {
            guard let n = brandNewByKind[kind], n > 0 else { continue }
            parts.append(kind.newCountPhrase(n))
        }
        if newCommentTotal > 0 {
            parts.append(String(localized: "\(newCommentTotal) new comments"))
        }
        // Shown on the Home summary card and spoken on arrival — was plain
        // English interpolation, so it never translated. Plural forms come
        // from the catalog's variations for these keys.
        guard !parts.isEmpty else {
            return String(localized: "\(newItems.count) new items since your last visit")
        }
        return String(localized: "\(ListFormatter.localizedString(byJoining: parts)) since your last visit")
    }
}
