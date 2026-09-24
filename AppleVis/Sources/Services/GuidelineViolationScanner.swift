import Combine
import Foundation

/// How far back a moderator scan looks. Deliberately just a few coarse
/// options rather than a free date picker — this is meant to be a quick
/// glance, not an archival search tool. Past Month is the slow one (a busy
/// month is a few thousand forum replies alone), which is part of why the
/// screen only scans when Start Scan is tapped rather than on open.
enum GuidelineScanRange: Int, CaseIterable, Identifiable {
    case day, threeDays, week, month

    var id: Self { self }

    var days: Int {
        switch self {
        case .day: return 1
        case .threeDays: return 3
        case .week: return 7
        case .month: return 30
        }
    }

    // Was returning bare string literals — `Text(r.displayName)` in
    // GuidelineViolationCheckView's Picker takes a `String`, and
    // `Text(_ content: String)` never consults the localization catalog the
    // way `Text(_ key: LocalizedStringKey)` does, so this Picker's three
    // options were silently never translated. Same bug class as
    // OnboardingHeader's title/subtitle; found while building
    // `AppHealthScanRange`'s identical enum for the App Directory Health
    // Check screen.
    var displayName: String {
        switch self {
        case .day: return String(localized: "Past Day")
        case .threeDays: return String(localized: "Past 3 Days")
        case .week: return String(localized: "Past Week")
        case .month: return String(localized: "Past Month")
        }
    }
}

/// One flagged piece of content — either a post/topic/entry's own body, or a
/// comment/reply/review underneath it. Reuses `GuidelinesChecker` unchanged:
/// the same rule engine that advises someone while composing their own
/// draft, run here against everyone's already-posted content instead.
/// `itemId`/`itemTitle` always identify the *root* content item (the topic,
/// post, episode, app entry, guide, or bug report), even when the flag is on
/// a comment underneath it — every detail view this navigates to
/// (`ForumTopicDetailView`, `BlogDetailView`, `AppDetailView`, etc.) shows
/// the full comment thread inline. `commentId`, when set, is that comment's
/// own id, separate from `itemId` — passed to the detail view's
/// `targetCommentId` so it scrolls/focuses straight to it instead of just
/// opening at the top of the thread.
struct GuidelineFlag: Identifiable {
    let id: String
    let kind: ContentKind
    let itemId: String
    let itemTitle: String
    let authorName: String
    let excerpt: String
    /// The full, un-excerpted body — kept separately from `excerpt` so the
    /// admin Edit/Share swipe actions have real content to work with rather
    /// than a truncated preview.
    let body: String
    let createdAt: Date
    let isRootItem: Bool
    let warnings: [GuidelineWarning]
    /// nil for a root item; the comment/reply/review's own id when this flag
    /// is on one of those underneath the root item.
    let commentId: String?
    /// Drupal JSON:API comment bundle (e.g. "comment_node_guides") for
    /// `editComment`/`unpublishComment`/`deleteComment` — set exactly when
    /// `commentId` is.
    let commentType: String?
    /// Drupal JSON:API node type suffix (e.g. "guides", "ios_app_directory")
    /// for `editNode`/`unpublishNode`/`deleteNode` — set exactly when this
    /// flag is on the root item itself (`commentId`/`commentType` are nil).
    let nodeType: String?

    var highestSeverity: GuidelineWarning.Severity {
        warnings.map(\.severity).min(by: { $0.sortOrder < $1.sortOrder }) ?? .low
    }

    /// The root item itself uses its content kind's own name ("Topic,"
    /// "Blog Post," "App Entry," …); a comment underneath it is always
    /// "Comment" — matching every actual comment thread page's own
    /// unified terminology (ForumTopicDetailView's header/actions/toasts
    /// all say "Comment" now, not "Reply"; App Entry reviews were the same
    /// fix, more recently). This used to special-case "Reply" for forums
    /// and "Review" for app entries, which just went stale once those
    /// pages themselves stopped using those words. Shared by the admin
    /// list row and its swipe actions so both agree on what to call a
    /// given flag. Reported directly.
    var kindLabel: String {
        isRootItem ? kind.displayName : String(localized: "Comment")
    }

    enum ActionTarget {
        case comment(type: String, id: String)
        case node(type: String, id: String)
    }

    /// What Edit/Unpublish/Delete should actually operate on — resolves to
    /// whichever of the comment or node identity this flag carries. `nil`
    /// only if the flag was constructed without either, which shouldn't
    /// happen for any flag this scanner produces.
    var actionTarget: ActionTarget? {
        if let commentId, let commentType { return .comment(type: commentType, id: commentId) }
        if let nodeType { return .node(type: nodeType, id: itemId) }
        return nil
    }
}

extension GuidelineWarning.Severity {
    /// High first, then medium, then low.
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}

/// Scans recently-posted content across every commentable content type —
/// forum topics/replies, blog posts, guides, podcast episodes, app/TV/Watch/
/// Mac directory entries and reviews, and bug reports — for possible
/// guideline violations, for the Guideline Violation Check admin screen.
///
/// Every content type, forums included, is scanned as two independent,
/// cheap direct queries, needing no per-item detail fetch:
/// 1. `node/<type>?sort=-created` — newly-*created* posts/entries, to catch
///    a flaggable root item, using the body already present in the list
///    response itself.
/// 2. `comment/<bundle>?sort=-created&include=uid,entity_id` — the newest
///    comments across *every* post of that bundle in one call (Drupal's
///    comment bundles are just as queryable unfiltered as filtered), with
///    the parent post's id/title coming back via `entity_id`'s include,
///    the same dynamic-entity-reference include pattern already proven
///    live for `FlagEndpoints`'s `flagged_entity`.
///
/// Forums used to be the exception: they paged the `/api/v1/forums/recent`
/// activity feed, then fetched each active topic's full detail to check its
/// replies. That detail fetch loads replies oldest-first, capped at 100, so
/// on any topic past 100 replies the newest ones — exactly the ones inside
/// the scan window — were silently never checked (five such topics were
/// active on the day this was found). It also went through the app's
/// 30-minute response cache, and cost one request per active topic. The
/// comment-bundle query has none of those problems, so forums now use it too.
@MainActor
final class GuidelineViolationScanner: ObservableObject {
    @Published private(set) var flags: [GuidelineFlag] = []
    @Published private(set) var isScanning = false
    /// Root items (topics, posts, entries) actually checked by the last scan.
    @Published private(set) var scannedPostCount = 0
    /// Comments/replies/reviews actually checked by the last scan.
    @Published private(set) var scannedCommentCount = 0
    /// The range the current results came from — nil until the first scan
    /// finishes. Kept separately from the screen's picker, which can be
    /// changed afterward without the results changing with it.
    @Published private(set) var lastScannedRange: GuidelineScanRange?
    @Published var error: String?

    /// Every item the last scan actually checked. Used to only count forum
    /// topics plus brand-new other posts — every comment, reply, and review
    /// was checked but left out, so a day with ~130 new items read as "20
    /// items scanned." Reported directly.
    var scannedItemCount: Int { scannedPostCount + scannedCommentCount }

    private var currentScanId = UUID()

    /// Drops one flag from the list right after its admin swipe action
    /// (Edit/Unpublish/Delete) succeeds — it's been handled, and re-running
    /// the same check against it would just show stale content anyway.
    func removeFlag(id: String) {
        flags.removeAll { $0.id == id }
    }

    /// One independently-scannable content stream: a node bundle plus its
    /// comment bundle. `kind` is shared across the four app-directory
    /// platforms (`ContentKind` doesn't distinguish them, and neither
    /// `AppDetailView` nor `BugDetailView` need a platform hint — both
    /// already resolve a bare content id by trying each of their own
    /// possible node types in turn).
    private struct ContentStream {
        let kind: ContentKind
        let nodeType: String
        let commentBundle: String
    }

    private static let streams: [ContentStream] = [
        ContentStream(kind: .forumTopic, nodeType: "forum", commentBundle: CommentBundle.forumTopic.rawValue),
        ContentStream(kind: .blogPost, nodeType: "blog2", commentBundle: CommentBundle.blogPost.rawValue),
        ContentStream(kind: .resource, nodeType: "guides", commentBundle: CommentBundle.guide.rawValue),
        ContentStream(kind: .podcastEpisode, nodeType: "podcast", commentBundle: CommentBundle.podcastEpisode.rawValue),
        ContentStream(kind: .appListing, nodeType: "ios_app_directory", commentBundle: CommentBundle.iosApp.rawValue),
        ContentStream(kind: .appListing, nodeType: "tv_directory", commentBundle: CommentBundle.tvApp.rawValue),
        ContentStream(kind: .appListing, nodeType: "watch_directory", commentBundle: CommentBundle.watchApp.rawValue),
        ContentStream(kind: .appListing, nodeType: "mac_app_directory", commentBundle: CommentBundle.macApp.rawValue),
        ContentStream(kind: .bugReport, nodeType: "ios_bug_report", commentBundle: CommentBundle.iosBugReport.rawValue),
        ContentStream(kind: .bugReport, nodeType: "os_x_bug_report", commentBundle: CommentBundle.macBugReport.rawValue),
    ]

    /// Safety cap on pages per query (50 items each, so 5,000 items) — well
    /// above a busy month of forum replies, the largest single stream, while
    /// still guaranteeing a misbehaving sort can't loop forever.
    private static let maxPages = 100

    func scan(range: GuidelineScanRange) async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        scannedPostCount = 0
        scannedCommentCount = 0

        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()

        let result = await Self.scanStreams(cutoff: cutoff)
        guard currentScanId == scanId else { return }

        lastScannedRange = range

        if result.failedQueries == Self.streams.count * 2 {
            // Was a raw string literal — `error: String?` shown via
            // `Text(error)` in GuidelineViolationCheckView, and `Text(String)`
            // doesn't consult the localization catalog at all, unlike
            // `Text(LocalizedStringKey)`. Wrapping it here, at the point the
            // value is actually produced, is what fixes it: whatever's
            // already stored in `error` just gets displayed as-is downstream.
            // Same fix as `AppEntryHealthScanner.scan()`'s identical case.
            error = String(localized: "Couldn't load recent activity. Try again.")
            isScanning = false
            return
        }

        scannedPostCount = result.postCount
        scannedCommentCount = result.commentCount
        flags = result.flags.sorted { a, b in
            if a.highestSeverity.sortOrder != b.highestSeverity.sortOrder {
                return a.highestSeverity.sortOrder < b.highestSeverity.sortOrder
            }
            return a.createdAt > b.createdAt
        }
        isScanning = false
    }

    // MARK: - Streams

    private struct RawPost {
        let id: String
        let title: String
        let authorName: String
        let createdAt: Date
        let body: String
    }

    private struct RawComment {
        let id: String
        let parentId: String
        let parentTitle: String
        let authorName: String
        let createdAt: Date
        let body: String
    }

    private struct StreamResult {
        var flags: [GuidelineFlag] = []
        var postCount = 0
        var commentCount = 0
        /// Queries (out of two per stream) that threw — used only to tell
        /// "everything failed" (show an error) apart from "a quiet day."
        var failedQueries = 0
    }

    private static func scanStreams(cutoff: Date) async -> StreamResult {
        await withTaskGroup(of: StreamResult.self) { group in
            for stream in streams {
                group.addTask { await scanStream(stream, cutoff: cutoff) }
            }
            var total = StreamResult()
            for await result in group {
                total.flags.append(contentsOf: result.flags)
                total.postCount += result.postCount
                total.commentCount += result.commentCount
                total.failedQueries += result.failedQueries
            }
            return total
        }
    }

    private static func scanStream(_ stream: ContentStream, cutoff: Date) async -> StreamResult {
        async let postsTask = recentPosts(nodeType: stream.nodeType, cutoff: cutoff)
        async let commentsTask = recentComments(bundle: stream.commentBundle, cutoff: cutoff)
        var result = StreamResult()
        let posts: [RawPost]
        let comments: [RawComment]
        do { posts = try await postsTask } catch { posts = []; result.failedQueries += 1 }
        do { comments = try await commentsTask } catch { comments = []; result.failedQueries += 1 }
        result.postCount = posts.count
        result.commentCount = comments.count

        for post in posts {
            let warnings = GuidelinesChecker.check(post.body)
            if !warnings.isEmpty {
                result.flags.append(GuidelineFlag(
                    id: "\(stream.nodeType)-post-\(post.id)", kind: stream.kind, itemId: post.id, itemTitle: post.title,
                    authorName: post.authorName, excerpt: .excerpt(from: post.body), body: post.body,
                    createdAt: post.createdAt, isRootItem: true, warnings: warnings,
                    commentId: nil, commentType: nil, nodeType: stream.nodeType
                ))
            }
        }

        for comment in comments {
            let warnings = GuidelinesChecker.check(comment.body, isReply: true)
            if !warnings.isEmpty {
                result.flags.append(GuidelineFlag(
                    id: "\(stream.commentBundle)-comment-\(comment.id)", kind: stream.kind, itemId: comment.parentId, itemTitle: comment.parentTitle,
                    authorName: comment.authorName, excerpt: .excerpt(from: comment.body), body: comment.body,
                    createdAt: comment.createdAt, isRootItem: false, warnings: warnings,
                    commentId: comment.id, commentType: stream.commentBundle, nodeType: nil
                ))
            }
        }

        return result
    }

    /// Newly-created posts/entries for one node bundle, newest first,
    /// stopping once a page's items fall outside the window.
    private static func recentPosts(nodeType: String, cutoff: Date) async throws -> [RawPost] {
        var results: [RawPost] = []
        var page = 0
        while page < maxPages {
            let response = try await APIClient.shared.jsonAPIList(
                "node/\(nodeType)",
                query: ["sort": "-created", "include": "uid", "page[limit]": "50", "page[offset]": "\(page * 50)"]
            )
            if response.data.isEmpty { break }
            let included = response.included ?? []
            var reachedCutoff = false
            for node in response.data {
                let created = node.createdDate
                if created < cutoff {
                    reachedCutoff = true
                    break
                }
                let uidId = node.relationshipId("uid")
                let userNode = uidId.flatMap { id in included.first { $0.id == id } }
                let authorName = userNode?.attributes["display_name"]?.stringValue
                    ?? userNode?.attributes["name"]?.stringValue ?? ""
                results.append(RawPost(
                    id: node.id,
                    title: node.attributes["title"]?.stringValue ?? "",
                    authorName: authorName,
                    createdAt: created,
                    body: node.attributes["body"]?.richTextValue ?? ""
                ))
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }

    /// Newest comments across *every* post of one comment bundle, newest
    /// first, stopping once a page's comments fall outside the window.
    private static func recentComments(bundle: String, cutoff: Date) async throws -> [RawComment] {
        var results: [RawComment] = []
        var page = 0
        while page < maxPages {
            let response = try await APIClient.shared.jsonAPIList(
                "comment/\(bundle)",
                query: ["sort": "-created", "include": "uid,entity_id", "page[limit]": "50", "page[offset]": "\(page * 50)"]
            )
            if response.data.isEmpty { break }
            let included = response.included ?? []
            var reachedCutoff = false
            for node in response.data {
                let created = node.createdDate
                if created < cutoff {
                    reachedCutoff = true
                    break
                }
                let c = Mappers.genericComment(node, included: included)
                let parentId = node.relationshipId("entity_id") ?? ""
                let parentTitle = included.first { $0.id == parentId }?.attributes["title"]?.stringValue ?? ""
                results.append(RawComment(
                    id: node.id, parentId: parentId, parentTitle: parentTitle,
                    authorName: c.authorName, createdAt: created, body: c.body
                ))
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }
}
