import Foundation

/// Pages whose saved copy is known to be behind the website: one you've
/// just commented on, or one Home says has new comments. The next time one
/// opens, it loads live instead of from the saved copy (or the phone's own
/// minute-old copy). A comment you'd just posted could otherwise be missing
/// for up to 15 minutes after leaving the page and coming back, while Home
/// already counted it. Reported by a beta tester (2026-10-09).
actor OutdatedPages {
    static let shared = OutdatedPages()
    private var keys: Set<String> = []
    /// Kinds of page that are all behind, from when: after editing or
    /// deleting a comment, where only the comment is known, not its page.
    private var kindsMarkedAt: [String: Date] = [:]
    private var loadedLiveAt: [String: Date] = [:]

    func mark(_ newKeys: [String]) {
        keys.formUnion(newKeys)
    }

    /// After a comment of `commentType` is edited, deleted, or unpublished:
    /// every page of that kind loads live once more.
    func markKind(ofCommentType commentType: String) {
        guard let prefix = Self.prefix(forCommentType: commentType) else { return }
        kindsMarkedAt[prefix] = Date()
    }

    /// True once per mark: the page loads live this time, then normally.
    func take(_ key: String) -> Bool {
        if keys.remove(key) != nil {
            loadedLiveAt[key] = Date()
            return true
        }
        for (prefix, markedAt) in kindsMarkedAt where key.hasPrefix(prefix) {
            if (loadedLiveAt[key] ?? .distantPast) < markedAt {
                loadedLiveAt[key] = Date()
                return true
            }
        }
        return false
    }

    private static func prefix(forCommentType commentType: String) -> String? {
        switch commentType {
        case "comment_forum": return "forums:detail:"
        case "comment_node_guides": return "resources:detail:"
        case "comment_node_blog2": return "blogs:detail:"
        case "comment_node_podcast": return "podcasts:"
        case "comment_node_ios_bug_report", "comment_node_os_x_bug_report": return "bugs:detail:"
        default: return commentType.hasPrefix("comment_node_") && commentType.hasSuffix("directory") ? "apps:detail:" : nil
        }
    }

    // MARK: The saved-copy keys each page uses

    static func forumTopic(_ id: String) -> [String] { ["forums:detail:\(id)"] }
    static func blogPost(_ id: String) -> [String] { ["blogs:detail:\(id)"] }
    static func guide(_ id: String) -> [String] { ["resources:detail:\(id)"] }
    /// The episode, and its comments, which load separately.
    static func podcastEpisode(_ id: String) -> [String] { ["podcasts:detail:\(id)", "podcasts:comments:\(id)"] }
    static func bugReport(_ id: String, platform: BugPlatform) -> [String] { ["bugs:detail:\(platform.rawValue):\(id)"] }
    /// Every platform's key, since an entry can be opened without knowing
    /// which directory it's in.
    static func appEntry(_ id: String) -> [String] {
        ["apps:detail:\(id)", "apps:detail:mac:\(id)", "apps:detail:tv:\(id)", "apps:detail:watch:\(id)"]
    }

    static func keys(for item: FeedItem) -> [String] {
        switch item {
        case .forumTopic(let topic):       return forumTopic(topic.id)
        case .podcastEpisode(let episode): return podcastEpisode(episode.id)
        case .appListing(let app):         return appEntry(app.id)
        case .resource(let resource):      return guide(resource.id)
        case .blogPost(let post):          return blogPost(post.id)
        }
    }

    /// After Home loads newer lists: every item whose comment count went
    /// up since the last lists.
    static func markChanged(from old: [FeedItem], to new: [FeedItem]) {
        let before = Dictionary(old.map { ($0.id, $0.commentCount) }, uniquingKeysWith: { first, _ in first })
        let changed = new.filter { item in before[item.id].map { item.commentCount > $0 } ?? false }
        guard !changed.isEmpty else { return }
        let keys = changed.flatMap { Self.keys(for: $0) }
        Task { await shared.mark(keys) }
    }
}
