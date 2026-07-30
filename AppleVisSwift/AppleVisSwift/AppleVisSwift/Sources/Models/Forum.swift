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
    let title: String
    let authorName: String
    let authorId: String
    let createdAt: Date
    let lastActivityAt: Date
    let replyCount: Int
    let viewCount: Int
    let category: String
    let categoryId: String
    let body: String
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
    func apply(to topics: [ForumTopic]) -> [ForumTopic] {
        let lastVisit = PersistenceStore.shared.forumsLastVisit
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
