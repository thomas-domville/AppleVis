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
        case .forumTopic(let t):     return FeedItem.visitKey(kind: .forumTopic, contentId: t.id)
        case .podcastEpisode(let e): return FeedItem.visitKey(kind: .podcastEpisode, contentId: e.id)
        case .appListing(let a):     return FeedItem.visitKey(kind: .appListing, contentId: a.id)
        case .resource(let r):       return FeedItem.visitKey(kind: .resource, contentId: r.id)
        case .blogPost(let b):       return FeedItem.visitKey(kind: .blogPost, contentId: b.id)
        }
    }

    /// The key used both here and by `PersistenceStore.stampItemVisit` —
    /// detail screens stamp a visit under this same key when opened, so
    /// Home's "new since last visit" tracking clears naturally on read
    /// instead of only ever clearing via Home's own "Mark as Read" action.
    static func visitKey(kind: ContentKind, contentId: String) -> String {
        switch kind {
        case .forumTopic:     return "forum-\(contentId)"
        case .podcastEpisode: return "podcast-\(contentId)"
        case .appListing:     return "app-\(contentId)"
        case .resource:       return "resource-\(contentId)"
        case .blogPost:       return "blog-\(contentId)"
        case .bugReport:      return "bug-\(contentId)"
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
