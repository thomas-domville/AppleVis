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
    /// Website link to exactly this item: a comment's own permalink
    /// (`/comment/{cid}#comment-{cid}`, which opens the thread at that
    /// comment) or the post's own page. Included when an admin shares a
    /// flag, so whoever receives it can open the real thing.
    var url: String? = nil
    /// The author is on the AppleVis editorial team (site editor or site
    /// admin), usually moderating: quoting a remark back or asking people to
    /// change something. Their tone flags are set aside. Only known when the
    /// site shares the author's roles with the signed-in admin. Suggested
    /// directly (2026-09-27).
    var authorIsEditorial: Bool = false
    /// A reply by the person who started the thread. The guidelines let
    /// developers share and discuss their own project in their own thread,
    /// so self-promotion is set aside for these, and Apple Intelligence is
    /// told. Reported directly (2026-10-06).
    var authorStartedThread: Bool = false
    /// The line that set off each rule, by rule id, when it can be found:
    /// shown above the preview so a long post's problem is easy to spot.
    /// Requested directly (2026-10-01).
    var triggers: [String: String] = [:]

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
    /// Posts and comments in the range that the English-only check, which
    /// blocks posting in the app, would have stopped. They're on the site,
    /// so most are probably English: this shows whether the check blocks
    /// real posts it shouldn't (app names, code, a quoted phrase). Admin
    /// only. Requested directly (2026-10-06).
    @Published private(set) var wouldBlockAsNotEnglish: [GuidelineFlag] = []
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
    /// Items checked so far in the scan that's running, for the Scanning
    /// row's live count.
    @Published private(set) var itemsCheckedSoFar = 0
    /// True between Stop and the scan actually winding down.
    @Published private(set) var isStopping = false
    /// The last scan was stopped early, so its results cover only part of
    /// the range.
    @Published private(set) var lastScanWasStopped = false
    private var scanTask: Task<StreamResult, Never>?

    /// Apple Intelligence's second opinion on each rule of each flag, by
    /// flag id then rule id, filled in after a scan on devices that support
    /// it. Only for rules that depend on context (see
    /// `GuidelineWarning.allowsSecondOpinion`). Each rule is judged on its
    /// own, so a flag that also has a clear-cut rule still gets a verdict on
    /// its context-dependent ones; it used to get none. Requested directly
    /// (2026-09-27, per rule 2026-09-30).
    @Published private(set) var opinions: [String: [String: IntelligenceService.GuidelineSecondOpinion]] = [:]

    /// Apple Intelligence judged every rule on this flag fine. Never true
    /// for a flag with a clear-cut or high-severity rule, since those are
    /// never judged.
    func isProbablyFine(_ flag: GuidelineFlag) -> Bool {
        guard let judged = opinions[flag.id], !flag.warnings.isEmpty else { return false }
        return flag.warnings.allSatisfy { judged[$0.id]?.isRealConcern == false }
    }
    /// Let Apple Intelligence read the conversation around a reply it still
    /// thinks breaks a guideline before deciding. A switch on the admin
    /// screen, so its verdicts can be compared with and without it. On by
    /// default. Requested directly (2026-10-06).
    static let readsConversationKey = "admin.guidelineReadsConversation"
    static var readsConversation: Bool {
        UserDefaults.standard.object(forKey: readsConversationKey) as? Bool ?? true
    }

    /// Asks Apple Intelligence again about the current flags, for instance
    /// after the conversation switch changes.
    func rerunReview() {
        reviewTask?.cancel()
        opinions = [:]
        reviewWithAppleIntelligence()
    }

    @Published private(set) var isReviewing = false
    @Published private(set) var reviewedCount = 0
    @Published private(set) var reviewTotal = 0
    private var reviewTask: Task<Void, Never>?

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

    /// Ends a long scan early and keeps what it's checked so far. Each
    /// content type stops before its next page. Requested directly.
    func stop() {
        guard isScanning, !isStopping else { return }
        isStopping = true
        scanTask?.cancel()
    }

    func scan(range: GuidelineScanRange) async {
        let scanId = UUID()
        currentScanId = scanId
        isScanning = true
        error = nil
        flags = []
        wouldBlockAsNotEnglish = []
        scannedPostCount = 0
        scannedCommentCount = 0
        itemsCheckedSoFar = 0
        isStopping = false
        lastScanWasStopped = false
        reviewTask?.cancel()
        opinions = [:]
        isReviewing = false

        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()

        let progress: @Sendable (Int) -> Void = { [weak self] count in
            Task { @MainActor [weak self] in
                guard let self, self.currentScanId == scanId else { return }
                self.itemsCheckedSoFar += count
            }
        }
        let task = Task { await Self.scanStreams(cutoff: cutoff, progress: progress) }
        scanTask = task
        let result = await task.value
        scanTask = nil
        guard currentScanId == scanId else { return }

        let wasStopped = isStopping
        isStopping = false
        lastScanWasStopped = wasStopped
        lastScannedRange = range

        if !wasStopped, result.failedQueries == Self.streams.count * 2 {
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
        wouldBlockAsNotEnglish = result.notEnglish.sorted { $0.createdAt > $1.createdAt }
        flags = result.flags.sorted { a, b in
            if a.highestSeverity.sortOrder != b.highestSeverity.sortOrder {
                return a.highestSeverity.sortOrder < b.highestSeverity.sortOrder
            }
            return a.createdAt > b.createdAt
        }
        isScanning = false
        reviewWithAppleIntelligence()
    }

    /// Asks Apple Intelligence about each context-dependent rule on each
    /// flag, one flag at a time in the background, so the results can be
    /// read straight away. A flag counts as probably fine only if every one
    /// of its rules is judged fine, so a clear-cut or high-severity rule
    /// always keeps it.
    private func reviewWithAppleIntelligence() {
        let candidates = flags.filter { $0.warnings.contains(where: \.allowsSecondOpinion) }
        guard IntelligenceService.isAvailable, !candidates.isEmpty else { return }
        reviewedCount = 0
        reviewTotal = candidates.count
        isReviewing = true
        let scanId = currentScanId
        let readsConversation = Self.readsConversation
        reviewTask = Task { [weak self] in
            // A thread is read once, however many of its comments are flagged.
            var conversations: [ConversationSource: ConversationContext?] = [:]
            for flag in candidates {
                guard !Task.isCancelled else { return }
                var judged: [String: IntelligenceService.GuidelineSecondOpinion] = [:]
                var source: ConversationSource?
                if readsConversation, let bundle = flag.commentType, let commentId = flag.commentId {
                    source = ConversationSource(commentBundle: bundle, nodeId: flag.itemId, flaggedCommentId: commentId)
                }
                for warning in flag.warnings where warning.allowsSecondOpinion {
                    let context = IntelligenceService.FlagContext(
                        threadTitle: flag.itemTitle, isReply: !flag.isRootItem, authorStartedThread: flag.authorStartedThread
                    )
                    let load: (() async -> ConversationContext?)? = source.map { source in
                        {
                            if let cached = conversations[source] { return cached }
                            let loaded = await GuidelineConversation.load(source)
                            conversations[source] = loaded
                            return loaded
                        }
                    }
                    let cacheKey = GuidelineOpinionCache.key(
                        flagId: flag.id, ruleId: warning.id, text: flag.body, readsConversation: readsConversation
                    )
                    if let saved = GuidelineOpinionCache.shared.opinion(for: cacheKey) {
                        judged[warning.id] = saved
                    } else if let opinion = await IntelligenceService.reviewFlag(warning, in: flag.body, context: context, loadConversation: load) {
                        judged[warning.id] = opinion
                        GuidelineOpinionCache.shared.store(opinion, for: cacheKey)
                    }
                }
                guard let self, !Task.isCancelled, self.currentScanId == scanId else { return }
                if !judged.isEmpty { self.opinions[flag.id] = judged }
                self.reviewedCount += 1
            }
            guard let self, self.currentScanId == scanId else { return }
            self.isReviewing = false
        }
    }

    // MARK: - Streams

    private struct RawPost {
        let id: String
        let title: String
        let authorName: String
        var authorIsEditorial = false
        let createdAt: Date
        let body: String
        let url: String?
    }

    private struct RawComment {
        let id: String
        let parentId: String
        let parentTitle: String
        let authorName: String
        var authorIsEditorial = false
        /// The comment's author also started the thread it's in.
        var startedThread = false
        let createdAt: Date
        let body: String
        let url: String?
    }

    /// A node's page on the website: its path alias, or /node/{nid}.
    private static func websiteURL(for node: JsonApiNode) -> String? {
        if let alias = node.attributes["path"]?.pathAlias, !alias.isEmpty {
            return "https://www.applevis.com\(alias)"
        }
        return node.attributes["drupal_internal__nid"]?.intValue.map { "https://www.applevis.com/node/\($0)" }
    }

    private struct StreamResult {
        var flags: [GuidelineFlag] = []
        var notEnglish: [GuidelineFlag] = []
        var postCount = 0
        var commentCount = 0
        /// Queries (out of two per stream) that threw — used only to tell
        /// "everything failed" (show an error) apart from "a quiet day."
        var failedQueries = 0
    }

    private static func scanStreams(cutoff: Date, progress: @escaping @Sendable (Int) -> Void) async -> StreamResult {
        await withTaskGroup(of: StreamResult.self) { group in
            for stream in streams {
                group.addTask { await scanStream(stream, cutoff: cutoff, progress: progress) }
            }
            var total = StreamResult()
            for await result in group {
                total.flags.append(contentsOf: result.flags)
                total.notEnglish.append(contentsOf: result.notEnglish)
                total.postCount += result.postCount
                total.commentCount += result.commentCount
                total.failedQueries += result.failedQueries
            }
            return total
        }
    }

    private static func scanStream(_ stream: ContentStream, cutoff: Date, progress: @escaping @Sendable (Int) -> Void) async -> StreamResult {
        async let postsTask = recentPosts(nodeType: stream.nodeType, cutoff: cutoff, progress: progress)
        async let commentsTask = recentComments(bundle: stream.commentBundle, parentNodeType: stream.nodeType, cutoff: cutoff, progress: progress)
        var result = StreamResult()
        let posts: [RawPost]
        let comments: [RawComment]
        do { posts = try await postsTask } catch { posts = []; result.failedQueries += 1 }
        do { comments = try await commentsTask } catch { comments = []; result.failedQueries += 1 }
        result.postCount = posts.count
        result.commentCount = comments.count

        for post in posts {
            if IntelligenceService.detectNonEnglish(HTMLText.plainText(fromHTML: post.body)) {
                result.notEnglish.append(GuidelineFlag(
                    id: "\(stream.nodeType)-post-\(post.id)-lang", kind: stream.kind, itemId: post.id, itemTitle: post.title,
                    authorName: post.authorName, excerpt: .excerpt(from: post.body), body: post.body,
                    createdAt: post.createdAt, isRootItem: true, warnings: [],
                    commentId: nil, commentType: nil, nodeType: stream.nodeType, url: post.url
                ))
            }
            let warnings = setAsideForEditorial(GuidelinesChecker.check(post.body), editorial: post.authorIsEditorial)
            if !warnings.isEmpty {
                result.flags.append(GuidelineFlag(
                    id: "\(stream.nodeType)-post-\(post.id)", kind: stream.kind, itemId: post.id, itemTitle: post.title,
                    authorName: post.authorName, excerpt: .excerpt(from: post.body), body: post.body,
                    createdAt: post.createdAt, isRootItem: true, warnings: warnings,
                    commentId: nil, commentType: nil, nodeType: stream.nodeType, url: post.url,
                    authorIsEditorial: post.authorIsEditorial,
                    triggers: Self.triggers(warnings, in: post.body, isReply: false)
                ))
            }
        }

        for comment in comments {
            if IntelligenceService.detectNonEnglish(HTMLText.plainText(fromHTML: comment.body)) {
                result.notEnglish.append(GuidelineFlag(
                    id: "\(stream.commentBundle)-comment-\(comment.id)-lang", kind: stream.kind, itemId: comment.parentId, itemTitle: comment.parentTitle,
                    authorName: comment.authorName, excerpt: .excerpt(from: comment.body), body: comment.body,
                    createdAt: comment.createdAt, isRootItem: false, warnings: [],
                    commentId: comment.id, commentType: stream.commentBundle, nodeType: nil, url: comment.url
                ))
            }
            var warnings = setAsideForEditorial(GuidelinesChecker.check(comment.body, isReply: true), editorial: comment.authorIsEditorial)
            if comment.startedThread { warnings.removeAll { $0.id == "self-promotion" } }
            if !warnings.isEmpty {
                result.flags.append(GuidelineFlag(
                    id: "\(stream.commentBundle)-comment-\(comment.id)", kind: stream.kind, itemId: comment.parentId, itemTitle: comment.parentTitle,
                    authorName: comment.authorName, excerpt: .excerpt(from: comment.body), body: comment.body,
                    createdAt: comment.createdAt, isRootItem: false, warnings: warnings,
                    commentId: comment.id, commentType: stream.commentBundle, nodeType: nil, url: comment.url,
                    authorIsEditorial: comment.authorIsEditorial, authorStartedThread: comment.startedThread,
                    triggers: Self.triggers(warnings, in: comment.body, isReply: true)
                ))
            }
        }

        return result
    }

    /// The line behind each rule, shortened to a readable length.
    private static func triggers(_ warnings: [GuidelineWarning], in body: String, isReply: Bool) -> [String: String] {
        var found: [String: String] = [:]
        for warning in warnings {
            if let text = GuidelinesChecker.triggeringText(for: warning.id, in: body, isReply: isReply) {
                found[warning.id] = text.count > 300 ? String(text.prefix(300)) + "…" : text
            }
        }
        return found
    }

    /// Editorial team posts keep every flag except tone: when they quote a
    /// remark back or ask people to change something, that's moderation.
    private static func setAsideForEditorial(_ warnings: [GuidelineWarning], editorial: Bool) -> [GuidelineWarning] {
        editorial ? warnings.filter { !$0.isToneConcern } : warnings
    }

    /// True if the included user has the site_editor or site_admin role.
    /// Drupal's JSON:API puts each role's machine name in the relationship's
    /// `meta.drupal_internal__target_id`; if roles aren't shared, it's false.
    private static func isEditorial(_ user: JsonApiNode?) -> Bool {
        guard let user else { return false }
        return user.relationshipTargetIds("roles").contains { $0 == "site_editor" || $0 == "site_admin" }
    }

    /// Newly-created posts/entries for one node bundle, newest first,
    /// stopping once a page's items fall outside the window.
    private static func recentPosts(nodeType: String, cutoff: Date, progress: @Sendable (Int) -> Void) async throws -> [RawPost] {
        var results: [RawPost] = []
        var page = 0
        while page < maxPages {
            // Stop keeps whatever's been checked; it doesn't throw it away.
            if Task.isCancelled { break }
            let response: JsonApiCollectionResponse
            do {
                // Only the fields this check reads, not every field on the
                // post. Verified live 2026-09-25. Requested directly.
                response = try await APIClient.shared.jsonAPIList(
                    "node/\(nodeType)",
                    query: [
                        "sort": "-created", "include": "uid", "page[limit]": "50", "page[offset]": "\(page * 50)",
                        "fields[node--\(nodeType)]": "title,body,created,path,drupal_internal__nid,uid",
                        "fields[user--user]": "display_name,name,roles",
                    ]
                )
            } catch {
                if Task.isCancelled { break }
                throw error
            }
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
                progress(1)
                results.append(RawPost(
                    id: node.id,
                    title: node.attributes["title"]?.stringValue ?? "",
                    authorName: authorName,
                    authorIsEditorial: isEditorial(userNode),
                    createdAt: created,
                    body: node.attributes["body"]?.richTextValue ?? "",
                    url: Self.websiteURL(for: node)
                ))
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }

    /// Newest comments across *every* post of one comment bundle, newest
    /// first, stopping once a page's comments fall outside the window.
    private static func recentComments(bundle: String, parentNodeType: String, cutoff: Date, progress: @Sendable (Int) -> Void) async throws -> [RawComment] {
        var results: [RawComment] = []
        var page = 0
        while page < maxPages {
            if Task.isCancelled { break }
            let response: JsonApiCollectionResponse
            do {
                // Only the fields this check reads. The included parent post
                // used to come back whole, body and all, just for its title;
                // now it's the title and link. About half the download per
                // page, verified live 2026-09-25. Requested directly.
                response = try await APIClient.shared.jsonAPIList(
                    "comment/\(bundle)",
                    query: [
                        "sort": "-created", "include": "uid,entity_id", "page[limit]": "50", "page[offset]": "\(page * 50)",
                        "fields[comment--\(bundle)]": "comment_body,created,name,drupal_internal__cid,uid,entity_id",
                        "fields[node--\(parentNodeType)]": "title,path,drupal_internal__nid,uid",
                        "fields[user--user]": "display_name,name,roles",
                    ]
                )
            } catch {
                if Task.isCancelled { break }
                throw error
            }
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
                let parent = included.first { $0.id == parentId }
                let parentTitle = parent?.attributes["title"]?.stringValue ?? ""
                // The comment's own permalink when Drupal gives its number;
                // otherwise the page it's on.
                let url = node.attributes["drupal_internal__cid"]?.intValue
                    .map { "https://www.applevis.com/comment/\($0)#comment-\($0)" }
                    ?? parent.flatMap(Self.websiteURL(for:))
                progress(1)
                let commentUserId = node.relationshipId("uid")
                let commentUser = commentUserId.flatMap { id in included.first { $0.id == id } }
                let startedThread = commentUserId != nil && parent?.relationshipId("uid") == commentUserId
                results.append(RawComment(
                    id: node.id, parentId: parentId, parentTitle: parentTitle,
                    authorName: c.authorName, authorIsEditorial: isEditorial(commentUser), startedThread: startedThread,
                    createdAt: created, body: c.body, url: url
                ))
            }
            if reachedCutoff { break }
            page += 1
        }
        return results
    }
}
