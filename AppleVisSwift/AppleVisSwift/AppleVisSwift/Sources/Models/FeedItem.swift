import Foundation

// A unified feed item used by the Home screen to show mixed content sorted by activity.
enum FeedItem: Identifiable {
    case forumTopic(ForumTopic)
    case podcastEpisode(PodcastEpisode)
    case appListing(AppListing)
    case resource(Resource)
    case blogPost(BlogPost)

    var id: String {
        switch self {
        case .forumTopic(let t):     return "forum-\(t.id)"
        case .podcastEpisode(let e): return "podcast-\(e.id)"
        case .appListing(let a):     return "app-\(a.id)"
        case .resource(let r):       return "resource-\(r.id)"
        case .blogPost(let b):       return "blog-\(b.id)"
        }
    }

    var title: String {
        switch self {
        case .forumTopic(let t):     return t.title
        case .podcastEpisode(let e): return e.title
        case .appListing(let a):     return a.name
        case .resource(let r):       return r.title
        case .blogPost(let b):       return b.title
        }
    }

    var lastActivityAt: Date {
        switch self {
        case .forumTopic(let t):     return t.lastActivityAt
        case .podcastEpisode(let e): return e.lastActivityAt
        case .appListing(let a):     return a.lastActivityAt
        case .resource(let r):       return r.updatedAt
        case .blogPost(let b):       return b.lastActivityAt
        }
    }

    var kind: ContentKind {
        switch self {
        case .forumTopic:     return .forumTopic
        case .podcastEpisode: return .podcastEpisode
        case .appListing:     return .appListing
        case .resource:       return .resource
        case .blogPost:       return .blogPost
        }
    }

    var isUnread: Bool {
        switch self {
        case .forumTopic(let t): return t.isUnread
        default: return false
        }
    }

    /// The count backing "new replies since you last saw this item" —
    /// replies/comments for most kinds, reviews for apps (apps have no
    /// comment concept of their own).
    var commentCount: Int {
        switch self {
        case .forumTopic(let t):     return t.replyCount
        case .podcastEpisode(let e): return e.commentCount
        case .appListing(let a):     return a.reviewCount
        case .resource(let r):       return r.commentCount
        case .blogPost(let b):       return b.commentCount
        }
    }
}
