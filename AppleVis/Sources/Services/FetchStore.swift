import Combine
import Foundation

// MARK: - Model

/// The original comment behind a Fetch row, kept so Reply can open the
/// right compose screen with it quoted.
enum FetchCommentSource {
    case forum(ForumReply)
    case blog(BlogComment)
    case resource(ResourceComment)
    case podcast(PodcastComment)
    case app(AppReview)
}

extension FetchCommentSource {
    /// Who wrote it, for owner-only Edit and Delete.
    var authorId: String {
        switch self {
        case .forum(let c): return c.authorId
        case .blog(let c): return c.authorId
        case .resource(let c): return c.authorId
        case .podcast(let c): return c.authorId
        case .app(let c): return c.authorId
        }
    }

    /// The text to start editing from, and the format to save it back in.
    var rawBody: String {
        switch self {
        case .forum(let c): return c.rawBody.isEmpty ? c.body.strippingHTMLTags() : c.rawBody
        case .blog(let c): return c.rawBody.isEmpty ? c.body.strippingHTMLTags() : c.rawBody
        case .resource(let c): return c.rawBody.isEmpty ? c.body.strippingHTMLTags() : c.rawBody
        case .podcast(let c): return c.body.strippingHTMLTags()
        case .app(let c): return c.rawBody.isEmpty ? c.body.strippingHTMLTags() : c.rawBody
        }
    }

    var bodyFormat: String {
        switch self {
        case .forum(let c): return c.bodyFormat
        case .blog(let c): return c.bodyFormat
        case .resource(let c): return c.bodyFormat
        case .podcast: return drupalDefaultTextFormat
        case .app(let c): return c.bodyFormat
        }
    }
}

/// One new comment in Fetch, read in full (one VoiceOver element each).
struct FetchComment: Identifiable, Hashable {
    static func == (a: FetchComment, b: FetchComment) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let author: String
    let date: Date
    let text: String
    /// Cut short only for a truly huge comment (a pasted log, say), so one
    /// element can't trap VoiceOver for minutes.
    let isTruncated: Bool
    /// "Replying to Jane", from Drupal's comment threading.
    let replyingTo: String?
    let source: FetchCommentSource
}

/// Everything Fetch shows for one new item beyond what Home already has.
struct FetchContent {
    let author: String
    let postedAt: Date
    /// Forum topics: the whole post. Guides, blog posts, podcasts, bugs:
    /// the first paragraph. App entries: an accessibility summary.
    let preview: String
    /// True when `preview` is only the start of the post.
    let previewIsExcerpt: Bool
    /// The new comments, oldest first, so the conversation reads in order.
    let comments: [FetchComment]
    /// The post's author, for owner-only Edit and Delete on forum topics.
    var authorId: String = ""
}

enum FetchLoadState {
    case loading
    case loaded(FetchContent)
    case failed
}

// MARK: - Store

/// Loads and caches each Fetch group's post preview and new comments, one
/// item at a time as it comes into view (or as Listen to Fetch reaches it),
/// so opening Fetch stays fast. Keyed by item and new-comment count, so a
/// fresh comment reloads that group.
@MainActor
final class FetchStore: ObservableObject {
    static let shared = FetchStore()

    @Published private(set) var states: [String: FetchLoadState] = [:]
    /// Items read to their end while "Mark as Read When Finished" is on.
    /// They're marked read only when leaving Fetch (switching views or
    /// leaving Home), never mid-read, so groups don't vanish while you're
    /// still in them.
    @Published var finishedIds: Set<String> = []
    private var inFlight: [String: Task<FetchContent?, Never>] = [:]

    static func key(_ item: FeedItem, newCount: Int) -> String { "\(item.id)#\(newCount)" }

    func state(for item: FeedItem, newCount: Int) -> FetchLoadState? {
        states[Self.key(item, newCount: newCount)]
    }

    /// Returns the content, loading it first if needed. Safe to call from
    /// several places at once; they share one request.
    @discardableResult
    func load(_ item: FeedItem, newCount: Int) async -> FetchContent? {
        let key = Self.key(item, newCount: newCount)
        if case .loaded(let content) = states[key] { return content }
        if let task = inFlight[key] { return await task.value }
        states[key] = .loading
        let task = Task { try? await FetchLoader.load(item, newCount: newCount) }
        inFlight[key] = task
        let content = await task.value
        inFlight[key] = nil
        states[key] = content.map { .loaded($0) } ?? .failed
        return content
    }

    func applyFinished(to vm: HomeViewModel) {
        guard !finishedIds.isEmpty else { return }
        for item in vm.newItems where finishedIds.contains(item.id) {
            vm.markAsRead(item)
        }
        finishedIds = []
    }

    /// After a comment is deleted or unpublished from Fetch.
    func removeComment(_ commentId: String, item: FeedItem, newCount: Int) {
        replaceComments(item: item, newCount: newCount) { $0.filter { $0.id != commentId } }
    }

    /// After a comment is edited from Fetch.
    func updateComment(_ commentId: String, newText: String, item: FeedItem, newCount: Int) {
        replaceComments(item: item, newCount: newCount) { comments in
            comments.map { c in
                guard c.id == commentId else { return c }
                let (text, cut) = FetchLoader.limited(FetchLoader.plainText(newText), FetchLoader.commentLimit)
                return FetchComment(id: c.id, author: c.author, date: c.date, text: text, isTruncated: cut, replyingTo: c.replyingTo, source: c.source)
            }
        }
    }

    private func replaceComments(item: FeedItem, newCount: Int, _ change: ([FetchComment]) -> [FetchComment]) {
        let key = Self.key(item, newCount: newCount)
        guard case .loaded(let content) = states[key] else { return }
        states[key] = .loaded(FetchContent(
            author: content.author, postedAt: content.postedAt, preview: content.preview,
            previewIsExcerpt: content.previewIsExcerpt, comments: change(content.comments), authorId: content.authorId
        ))
    }

    func retry(_ item: FeedItem, newCount: Int) async {
        states[Self.key(item, newCount: newCount)] = nil
        await load(item, newCount: newCount)
    }
}

// MARK: - Loader

/// Fetches one item's detail and exactly its newest comments, reusing the
/// same endpoints each detail page uses, paging only as far as needed.
enum FetchLoader {
    /// Longest comment read as one element; see `FetchComment.isTruncated`.
    static let commentLimit = 4000
    /// Longest excerpt for a guide, blog post, podcast, or bug.
    static let excerptLimit = 700
    /// Longest forum post shown whole before it's cut short.
    static let postLimit = 4000

    @MainActor
    static func load(_ item: FeedItem, newCount: Int) async throws -> FetchContent {
        let api = APIClient.shared
        switch item {
        case .forumTopic(let topic):
            let detail = try await api.forums.topicDetail(id: topic.id)
            let replies = try await newest(newCount, loaded: detail.replies, total: detail.replyCount) {
                try await api.forums.moreReplies(topicId: topic.id, offset: $0)
            }
            // Authors of every reply loaded, to name who a reply answers.
            let byId = Dictionary((detail.replies + replies).map { ($0.id, $0.authorName) }, uniquingKeysWith: { a, _ in a })
            let (post, cut) = limited(plainText(detail.body), postLimit)
            return FetchContent(
                author: detail.authorName, postedAt: detail.createdAt, preview: post, previewIsExcerpt: cut,
                comments: replies.map { comment($0.id, $0.authorName, $0.createdAt, $0.body, source: .forum($0), replyingTo: $0.parentId.flatMap { byId[$0] }) },
                authorId: detail.authorId
            )

        case .blogPost(let post):
            let detail = try await api.blogs.detail(id: post.id)
            let comments = try await newest(newCount, loaded: detail.comments, total: detail.commentCount) {
                try await api.blogs.moreComments(blogId: post.id, offset: $0)
            }
            let (excerpt, cut) = firstParagraph(detail.body)
            return FetchContent(
                author: detail.authorName, postedAt: detail.publishedAt, preview: excerpt, previewIsExcerpt: cut,
                comments: comments.map { comment($0.id, $0.authorName, $0.createdAt, $0.body, source: .blog($0)) }
            )

        case .resource(let resource):
            let detail = try await api.resources.detail(id: resource.id)
            let comments = try await newest(newCount, loaded: detail.comments, total: detail.commentCount) {
                try await api.resources.moreComments(resourceId: resource.id, offset: $0)
            }
            let (excerpt, cut) = firstParagraph(detail.body)
            return FetchContent(
                author: detail.authorName, postedAt: detail.createdAt, preview: excerpt, previewIsExcerpt: cut,
                comments: comments.map { comment($0.id, $0.authorName, $0.createdAt, $0.body, source: .resource($0)) }
            )

        case .podcastEpisode(let episode):
            async let fullEpisode = api.podcasts.episode(id: episode.id)
            let firstComments = newCount > 0 ? try await api.podcasts.comments(episodeId: episode.id) : []
            let full = try await fullEpisode
            let comments = try await newest(newCount, loaded: firstComments, total: full.commentCount) {
                try await api.podcasts.moreComments(episodeId: episode.id, offset: $0)
            }
            let (excerpt, cut) = firstParagraph(full.description)
            return FetchContent(
                author: full.authorName, postedAt: full.publishedAt, preview: excerpt, previewIsExcerpt: cut,
                comments: comments.map { comment($0.id, $0.authorName, $0.createdAt, $0.body, source: .podcast($0)) }
            )

        case .appListing(let app):
            let detail = try await api.apps.detail(id: app.id, platform: app.platform)
            let reviews = try await newest(newCount, loaded: detail.reviews, total: detail.reviewCount) {
                try await api.apps.moreReviews(appId: app.id, offset: $0, platform: app.platform)
            }
            return FetchContent(
                author: detail.submittedBy, postedAt: detail.createdAt, preview: appSummary(detail), previewIsExcerpt: true,
                comments: reviews.map { comment($0.id, $0.authorName, $0.createdAt, $0.body, source: .app($0)) }
            )
        }
    }

    // MARK: Paging

    /// The newest `count` comments, oldest first. Comments arrive oldest
    /// first, so this pages forward until everything up to `total` is in
    /// hand (capped, as a safety net), then keeps the last `count`.
    @MainActor
    static func newest<T>(_ count: Int, loaded: [T], total: Int, more: (Int) async throws -> [T]) async throws -> [T] {
        guard count > 0 else { return [] }
        var all = loaded
        var pages = 0
        while all.count < total && pages < 40 {
            let batch = try await more(all.count)
            if batch.isEmpty { break }
            all += batch
            pages += 1
        }
        return Array(all.suffix(count))
    }

    // MARK: Text

    static func comment(_ id: String, _ author: String, _ date: Date, _ html: String, source: FetchCommentSource, replyingTo: String? = nil) -> FetchComment {
        let (text, cut) = limited(plainText(html), commentLimit)
        return FetchComment(id: id, author: author, date: date, text: text, isTruncated: cut, replyingTo: replyingTo, source: source)
    }

    /// HTML to readable text: quoted earlier comments dropped (they'd just
    /// repeat what was already read), tags stripped, paragraphs kept.
    static func plainText(_ html: String) -> String {
        let withoutQuotes = html.replacingOccurrences(
            of: #"<blockquote[\s\S]*?</blockquote>"#, with: " ", options: [.regularExpression, .caseInsensitive]
        )
        let paragraphed = withoutQuotes
            .replacingOccurrences(of: #"</p>|<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        return paragraphed.strippingHTMLTags()
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// The first real paragraph, for long content that's opened to read in full.
    static func firstParagraph(_ html: String) -> (String, Bool) {
        let paragraphs = plainText(html).components(separatedBy: "\n")
        guard let first = paragraphs.first else { return ("", false) }
        let (text, cut) = limited(first, excerptLimit)
        return (text, cut || paragraphs.count > 1)
    }

    /// Cuts at the last sentence end before `limit` when there is one.
    static func limited(_ text: String, _ limit: Int) -> (String, Bool) {
        guard text.count > limit else { return (text, false) }
        let head = String(text.prefix(limit))
        if let end = head.lastIndex(where: { ".!?".contains($0) }), head.distance(from: head.startIndex, to: end) > limit / 2 {
            return (String(head[...end]), true)
        }
        return (head.trimmingCharacters(in: .whitespaces) + "…", true)
    }

    /// For an app entry, what members actually want to know: platform,
    /// category, how it works with VoiceOver, price, and the start of the
    /// submitter's accessibility notes.
    static func appSummary(_ detail: AppDetail) -> String {
        var parts = [detail.platform.displayName]
        if !detail.category.isEmpty { parts.append(detail.category) }
        var lines = [parts.joined(separator: " · ")]
        if let performance = detail.voiceOverPerformance?.trimmingCharacters(in: .whitespaces), !performance.isEmpty {
            lines.append(String(localized: "VoiceOver performance: \(performance)"))
        }
        if !detail.price.isEmpty {
            lines.append(String(localized: "Price: \(detail.price)"))
        }
        let notes = firstParagraph(detail.accessibilityComments ?? detail.body).0
        if !notes.isEmpty { lines.append(notes) }
        return lines.joined(separator: "\n")
    }
}
