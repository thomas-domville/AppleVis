import Foundation

struct ForumTopic: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let authorName: String
    let authorId: String
    let createdAt: Date
    let lastActivityAt: Date
    let replyCount: Int
    let category: String
    let categoryId: String
    let url: String
    var isUnread: Bool
    var isFollowing: Bool
    var isSaved: Bool
}

struct ForumTopicDetail: Identifiable, Codable {
    let id: String
    /// Drupal's internal integer node ID (distinct from `id`, the JSON:API
    /// UUID) — needed to call History's `/history/{nid}/read`, which is
    /// keyed on the classic integer ID like the rest of Drupal core.
    let nid: Int
    // title/body are var, not let: an admin/owner editing the topic from
    // its own detail screen updates these in place after a successful save.
    var title: String
    let authorName: String
    let authorId: String
    let createdAt: Date
    let lastActivityAt: Date
    // Not let: incremented in place after a successful reply post so the
    // UI reflects the new count without a full re-fetch.
    var replyCount: Int
    let viewCount: Int
    let category: String
    let categoryId: String
    var body: String
    let url: String
    var isFollowing: Bool
    var isSaved: Bool
    var replies: [ForumReply]
}

struct ForumReply: Identifiable, Codable {
    let id: String
    let subject: String
    let authorName: String
    let authorId: String
    let body: String
    let createdAt: Date
    let loveCount: Int
    var isNew: Bool
}

struct ForumCategory: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tid: Int
    let topicCount: Int
}

extension ForumFilter {
    /// Applies this filter to a page of "recent" topics. Not meaningful for
    /// `.following`/`.saved` — those are sourced directly from
    /// `PersistenceStore` (see `supportsRefinement`), not from "recent".
    ///
    /// `lastVisit` is passed in rather than read from `PersistenceStore`
    /// directly — the caller is responsible for capturing one stable
    /// snapshot per genuine visit (see `ForumsBrowseView.sessionLastVisit`).
    /// Reading the live, ever-advancing store value here directly caused
    /// FORUM-01: `forumsLastVisit` was re-stamped to "now" on every reload,
    /// so `.new`/`.sinceLastVisit` compared against a timestamp of "this
    /// exact moment" and were almost always empty.
    func apply(to topics: [ForumTopic], lastVisit: Date) -> [ForumTopic] {
        switch self {
        case .recent:
            return topics
        case .new:
            return topics.filter { $0.createdAt > lastVisit }
        case .unread:
            return topics.filter { !PersistenceStore.shared.isTopicSeen(id: $0.id) }
        case .sinceLastVisit:
            return topics.filter { $0.lastActivityAt > lastVisit }
        case .following, .saved:
            return topics
        }
    }
}
