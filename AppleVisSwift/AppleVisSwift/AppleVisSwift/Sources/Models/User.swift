import Foundation

struct AuthUser: Codable {
    let uid: String
    let uuid: String
    let name: String
    let csrfToken: String
    let logoutToken: String
    let roles: [String]
    var isAdmin: Bool { roles.contains("administrator") }
}

struct UserProfile: Identifiable, Codable {
    let id: String
    let uid: String
    let name: String
    let email: String?
    let memberSince: Date
    let postCount: Int
    let profileUrl: String
}

struct SavedItem: Identifiable, Codable {
    let id: String
    let kind: ContentKind
    let title: String
    let savedAt: Date
    let lastActivityAt: Date?
}

struct FollowedItem: Identifiable, Codable {
    let id: String
    let kind: ContentKind
    let nodeType: String
    let title: String
    let followedAt: Date
    let lastActivityAt: Date?
    let url: String
}

/// A push notification the user received, kept locally so Home can show a
/// "Notification summary" (docs/APPLEVIS_2026_1_MASTER_SPEC.md) — nothing
/// server-side tracks notification history, so this is purely on-device.
struct NotificationHistoryItem: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let receivedAt: Date
    /// Nil when the payload didn't carry a recognizable deep-link target —
    /// still shown in history, just not tappable-to-open.
    let kind: ContentKind?
    let contentId: String?
}

// Unified content type enum used throughout the app
enum ContentKind: String, Codable, CaseIterable {
    case forumTopic
    case podcastEpisode
    case appListing
    case resource
    case blogPost
    case bugReport

    var displayName: String {
        switch self {
        case .forumTopic:     return "Forum Topic"
        case .podcastEpisode: return "Podcast"
        case .appListing:     return "App"
        case .resource:       return "Guide"
        case .blogPost:       return "Blog Post"
        case .bugReport:      return "Bug Report"
        }
    }

    /// JSON:API resource type — used for follow/unfollow flagging, which is
    /// generic across content types.
    var nodeType: String {
        switch self {
        case .forumTopic:     return "node--forum"
        case .podcastEpisode: return "node--podcast"
        case .appListing:     return "node--ios_app_directory"
        case .resource:       return "node--guides"
        case .blogPost:       return "node--blog2"
        case .bugReport:      return "node--ios_bug_report"
        }
    }

    var systemImage: String {
        switch self {
        case .forumTopic:     return "bubble.left.and.bubble.right"
        case .podcastEpisode: return "mic"
        case .appListing:     return "square.grid.2x2"
        case .resource:       return "book"
        case .blogPost:       return "newspaper"
        case .bugReport:      return "ant"
        }
    }
}
