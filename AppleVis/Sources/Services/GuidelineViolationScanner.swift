import Combine
import Foundation

/// How far back a moderator scan looks. Deliberately just three coarse
/// options rather than a free date picker — this is meant to be a quick
/// glance, not an archival search tool.
enum GuidelineScanRange: Int, CaseIterable, Identifiable {
    case day, threeDays, week

    var id: Self { self }

    var days: Int {
        switch self {
        case .day: return 1
        case .threeDays: return 3
        case .week: return 7
        }
    }

    var displayName: String {
        switch self {
        case .day: return "Past Day"
        case .threeDays: return "Past 3 Days"
        case .week: return "Past Week"
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
/// the full comment thread inline, so there's no separate "jump to this one
/// comment" destination to resolve.
struct GuidelineFlag: Identifiable {
    let id: String
    let kind: ContentKind
    let itemId: String
    let itemTitle: String
    let authorName: String
    let excerpt: String
    let createdAt: Date
    let isRootItem: Bool
    let warnings: [GuidelineWarning]

    var highestSeverity: GuidelineWarning.Severity {
        warnings.map(\.severity).min(by: { $0.sortOrder < $1.sortOrder }) ?? .low
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
/// guideline violations, for the Moderator Tools admin screen.
///
/// Forums use the native `/api/v1/forums/recent` feed (see
/// `ForumEndpoints.recent`), which is sorted by real last-comment activity —
/// the only content type with such a feed. Every other type has no
/// equivalent: JSON:API's `-changed` sort on the node itself doesn't move
/// when a new comment lands on an old post, so paging a node listing by
/// "recently changed" would silently miss a fresh, flaggable comment on
/// month-old content — the exact gap a moderation scan can't afford.
///
/// Instead, each of those content types is scanned as two independent,
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
@MainActor
final class GuidelineViolationScanner: ObservableObject {
    @Published private(set) var flags: [GuidelineFlag] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scannedItemCount = 0
    @Published var error: String?

    private var currentScanId = UUID()

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

    func scan(range: GuidelineScanRange) async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        scannedItemCount = 0

        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()

        async let topicsTask = Self.recentlyActiveTopics(since: cutoff)
        async let streamResults = Self.scanStreams(cutoff: cutoff)

        let topics = (try? await topicsTask) ?? []
        guard currentScanId == scanId else { return }
        let topicFlags = await Self.scanTopics(topics, cutoff: cutoff)
        let (streamFlags, streamScannedCount) = await streamResults
        guard currentScanId == scanId else { return }

        scannedItemCount = topics.count + streamScannedCount

        if topics.isEmpty, streamScannedCount == 0 {
            error = "Couldn't load recent activity. Try again."
            isScanning = false
            return
        }

        flags = (topicFlags + streamFlags).sorted { a, b in
            if a.highestSeverity.sortOrder != b.highestSeverity.sortOrder {
                return a.highestSeverity.sortOrder < b.highestSeverity.sortOrder
            }
            return a.createdAt > b.createdAt
        }
        isScanning = false
    }

    // MARK: - Forums

    /// Pages through `forums/recent` (already sorted by last activity, and
    /// deliberately `appleOnly: false` — this tool covers everything, no
    /// Home-style content filtering) until a page's topics fall outside the
    /// window, then stops. Safety-capped at 50 pages so a runaway loop
    /// can't hang indefinitely if the sort order ever misbehaves.
    private static func recentlyActiveTopics(since cutoff: Date) async throws -> [ForumTopic] {
        var results: [ForumTopic] = []
        var page = 0
        while page < 50 {
            let batch = try await APIClient.shared.forums.recent(page: page, appleOnly: false)
            if batch.isEmpty { break }
            var reachedCutoff = false
            for topic in batch {
                if topic.lastActivityAt < cutoff {
                    reachedCutoff = true
                    break
                }
                results.append(topic)
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }

    /// Bounded concurrency (4 at a time) — fetching every candidate topic's
    /// full detail at once would be a needless burst against the API for a
    /// busy week; this stays a reasonable citizen while still being much
    /// faster than doing them one at a time.
    private static func scanTopics(_ topics: [ForumTopic], cutoff: Date) async -> [GuidelineFlag] {
        var results: [GuidelineFlag] = []
        await withTaskGroup(of: [GuidelineFlag].self) { group in
            var iterator = topics.makeIterator()
            let maxConcurrent = 4
            for _ in 0..<maxConcurrent {
                guard let topic = iterator.next() else { break }
                group.addTask { await scanTopic(topic, cutoff: cutoff) }
            }
            while let topicFlags = await group.next() {
                results.append(contentsOf: topicFlags)
                if let topic = iterator.next() {
                    group.addTask { await scanTopic(topic, cutoff: cutoff) }
                }
            }
        }
        return results
    }

    private static func scanTopic(_ topic: ForumTopic, cutoff: Date) async -> [GuidelineFlag] {
        guard let detail = try? await APIClient.shared.forums.topicDetail(id: topic.id) else { return [] }
        var flags: [GuidelineFlag] = []

        if detail.createdAt >= cutoff {
            let warnings = GuidelinesChecker.check(detail.body)
            if !warnings.isEmpty {
                flags.append(GuidelineFlag(
                    id: "topic-\(detail.id)", kind: .forumTopic, itemId: detail.id, itemTitle: detail.title,
                    authorName: detail.authorName, excerpt: .excerpt(from: detail.body),
                    createdAt: detail.createdAt, isRootItem: true, warnings: warnings
                ))
            }
        }

        for reply in detail.replies where reply.createdAt >= cutoff {
            let warnings = GuidelinesChecker.check(reply.body)
            if !warnings.isEmpty {
                flags.append(GuidelineFlag(
                    id: "reply-\(reply.id)", kind: .forumTopic, itemId: detail.id, itemTitle: detail.title,
                    authorName: reply.authorName, excerpt: .excerpt(from: reply.body),
                    createdAt: reply.createdAt, isRootItem: false, warnings: warnings
                ))
            }
        }

        return flags
    }

    // MARK: - Every other content type

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

    private static func scanStreams(cutoff: Date) async -> (flags: [GuidelineFlag], scannedCount: Int) {
        await withTaskGroup(of: (flags: [GuidelineFlag], scannedCount: Int).self) { group in
            for stream in streams {
                group.addTask { await scanStream(stream, cutoff: cutoff) }
            }
            var allFlags: [GuidelineFlag] = []
            var totalScanned = 0
            for await result in group {
                allFlags.append(contentsOf: result.flags)
                totalScanned += result.scannedCount
            }
            return (allFlags, totalScanned)
        }
    }

    private static func scanStream(_ stream: ContentStream, cutoff: Date) async -> (flags: [GuidelineFlag], scannedCount: Int) {
        async let postsTask = recentPosts(nodeType: stream.nodeType, cutoff: cutoff)
        async let commentsTask = recentComments(bundle: stream.commentBundle, cutoff: cutoff)
        let posts = (try? await postsTask) ?? []
        let comments = (try? await commentsTask) ?? []

        var flags: [GuidelineFlag] = []

        for post in posts {
            let warnings = GuidelinesChecker.check(post.body)
            if !warnings.isEmpty {
                flags.append(GuidelineFlag(
                    id: "\(stream.nodeType)-post-\(post.id)", kind: stream.kind, itemId: post.id, itemTitle: post.title,
                    authorName: post.authorName, excerpt: .excerpt(from: post.body),
                    createdAt: post.createdAt, isRootItem: true, warnings: warnings
                ))
            }
        }

        for comment in comments {
            let warnings = GuidelinesChecker.check(comment.body)
            if !warnings.isEmpty {
                flags.append(GuidelineFlag(
                    id: "\(stream.commentBundle)-comment-\(comment.id)", kind: stream.kind, itemId: comment.parentId, itemTitle: comment.parentTitle,
                    authorName: comment.authorName, excerpt: .excerpt(from: comment.body),
                    createdAt: comment.createdAt, isRootItem: false, warnings: warnings
                ))
            }
        }

        return (flags, posts.count)
    }

    /// Newly-created posts/entries for one node bundle, newest first,
    /// stopping once a page's items fall outside the window. Safety-capped
    /// at 10 pages (500 items) — recently-*created* content in a single-week
    /// window is a much smaller set than forums' full recent-activity feed.
    private static func recentPosts(nodeType: String, cutoff: Date) async throws -> [RawPost] {
        var results: [RawPost] = []
        var page = 0
        while page < 10 {
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
        while page < 10 {
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
