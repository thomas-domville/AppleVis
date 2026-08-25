import Foundation

struct AuthUser: Codable {
    let uid: String
    let uuid: String
    let name: String
    let csrfToken: String
    let logoutToken: String
    let roles: [String]
    /// Confirmed directly by the site's Drupal developer: the site has no
    /// "administrator" role at all — its two editorial roles are machine-
    /// named `site_editor` and `site_admin` (the other three role machine
    /// names, `anonymous`/`authenticated`/`moderated_user`, are ordinary
    /// user-level roles, not editorial ones). `roles` here already carries
    /// real machine names, not display labels — see
    /// `AccountEndpoints.resolveRoles`'s `drupal_internal__target_id`
    /// read — so this was previously checking for a role name that could
    /// never actually appear, meaning Edit/Unpublish/Delete for
    /// non-owned content silently never unlocked for anyone, regardless of
    /// their real site role. Reported directly.
    var isAdmin: Bool { roles.contains("site_editor") || roles.contains("site_admin") }
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
        case .forumTopic:     return "Topic"
        case .podcastEpisode: return "Podcast"
        case .appListing:     return "App Entry"
        case .resource:       return "Guide"
        case .blogPost:       return "Blog Post"
        case .bugReport:      return "Bug Report"
        }
    }

    /// Used specifically for the Save/Unsave action wording — everywhere
    /// else `displayName`'s "Podcast" is correct (you're following/sharing/
    /// opening the show), but "Save Podcast" reads as ambiguous about
    /// whether the whole show or just this one episode gets saved. "Save
    /// Episode" says exactly what's being saved. Reported directly by a
    /// VoiceOver user after noticing Save/Follow wording was the one place
    /// on every row that never named the content kind at all.
    var saveActionNoun: String {
        self == .podcastEpisode ? "Episode" : displayName
    }

    /// Lowercased, correctly-pluralized `displayName` for count summaries
    /// ("20 new topics," "18 new app entries") — naively appending "s"
    /// broke for "App Entry" ("18 new app entrys").
    func displayNamePlural(_ count: Int) -> String {
        guard count != 1 else { return displayName.lowercased() }
        switch self {
        case .appListing: return "app entries"
        default:          return displayName.lowercased() + "s"
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
