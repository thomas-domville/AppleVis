import CoreSpotlight
import UniformTypeIdentifiers

/// Indexes browsed content into system-wide Spotlight search. Each item's
/// unique identifier encodes its content kind so a tap from Spotlight can be
/// routed back to the right detail screen (see AppleVisApp's
/// `onContinueUserActivity(CSSearchableItemActionType.searchableItemActionType)`).
enum SpotlightIndexer {
    static func identifier(kind: ContentKind, id: String) -> String {
        "applevis.\(kind.rawValue).\(id)"
    }

    static func parse(identifier: String) -> (kind: ContentKind, id: String)? {
        let parts = identifier.split(separator: ".", maxSplits: 2)
        guard parts.count == 3, parts[0] == "applevis", let kind = ContentKind(rawValue: String(parts[1])) else { return nil }
        return (kind, String(parts[2]))
    }

    static func index(kind: ContentKind, id: String, title: String, contentDescription: String, url: String?) {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.text)
        attributes.title = title
        attributes.contentDescription = contentDescription
        if let url, let contentURL = URL(string: url) { attributes.contentURL = contentURL }

        let item = CSSearchableItem(
            uniqueIdentifier: identifier(kind: kind, id: id),
            domainIdentifier: kind.rawValue,
            attributeSet: attributes
        )
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    /// Removes a single item from the Spotlight index — e.g. after it's
    /// deleted. RN's native Spotlight module (never actually called from any
    /// RN screen) designed for this via `deleteSearchableItems`; Swift's
    /// port only ever indexed, with no way to remove anything.
    static func deindex(kind: ContentKind, id: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier(kind: kind, id: id)])
    }

    /// Clears every AppleVis item from system Spotlight — called on sign-out
    /// so a shared device doesn't keep surfacing another user's browsing
    /// history in search after they've signed out.
    static func deindexAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ContentKind.allCases.map(\.rawValue))
    }

    static func index(_ topic: ForumTopic) {
        index(kind: .forumTopic, id: topic.id, title: topic.title, contentDescription: "\(topic.category) · \(String(localized: "\(topic.replyCount) replies"))", url: topic.url)
    }

    static func index(_ episode: PodcastEpisode) {
        index(kind: .podcastEpisode, id: episode.id, title: episode.title, contentDescription: episode.showTitle, url: episode.url)
    }

    static func index(_ app: AppListing) {
        index(kind: .appListing, id: app.id, title: app.name, contentDescription: "\(app.developer) · \(app.category)", url: app.url)
    }

    static func index(_ resource: Resource) {
        index(kind: .resource, id: resource.id, title: resource.title, contentDescription: resource.summary, url: resource.url)
    }

    static func index(_ post: BlogPost) {
        index(kind: .blogPost, id: post.id, title: post.title, contentDescription: post.summary, url: post.url)
    }

    static func index(_ bug: BugReport) {
        index(kind: .bugReport, id: bug.id, title: bug.title, contentDescription: "\(bug.platform.displayName) · \(bug.status.displayName) · \(bug.summary)", url: bug.url)
    }

    // MARK: - Help, saved, and followed (2026-09-28)

    private static let helpDomain = "help"
    private static let helpIndexedVersionKey = "spotlight.helpIndexedVersion"

    static func helpIdentifier(_ articleId: String) -> String { "applevis.help.\(articleId)" }

    /// The Help article a Spotlight result points to, if it's one.
    static func helpArticle(forIdentifier identifier: String) -> HelpArticle? {
        let prefix = "applevis.help."
        guard identifier.hasPrefix(prefix) else { return nil }
        let id = String(identifier.dropFirst(prefix.count))
        return MouseKnowledge.allHelpArticles.first { $0.id == id }
    }

    /// Puts every Help article in Spotlight, so searching iOS for "Trim
    /// Silence" finds the article that explains it. Only redone when the
    /// app's build changes, since Help only changes with an update. Kept
    /// on sign-out: it's the app's own text, not anyone's history.
    /// Requested directly.
    static func indexHelpArticlesIfNeeded() {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        guard UserDefaults.standard.string(forKey: helpIndexedVersionKey) != build else { return }
        let items = MouseKnowledge.allHelpArticles.map { article -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: UTType.text)
            attributes.title = article.title
            attributes.contentDescription = article.summary
            attributes.textContent = MouseKnowledge.helpArticleText(article)
            attributes.keywords = ["AppleVis", "Help"]
            return CSSearchableItem(uniqueIdentifier: helpIdentifier(article.id), domainIdentifier: helpDomain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [helpDomain]) { _ in
            index.indexSearchableItems(items) { error in
                if error == nil { UserDefaults.standard.set(build, forKey: helpIndexedVersionKey) }
            }
        }
    }

    /// Saved and followed items, so Spotlight finds them even if they were
    /// saved or followed on another device and never opened on this one.
    /// Uses the same identifiers as everything else, so tapping one opens
    /// it in the app, and sign-out clears them with the rest.
    @MainActor
    static func indexSavedAndFollowed() {
        let saved = PersistenceStore.shared.savedItems().map { item in
            searchableItem(kind: item.kind, id: item.id, title: item.title,
                           contentDescription: String(localized: "Saved in AppleVis"), url: nil)
        }
        let followed = PersistenceStore.shared.followedItems().map { item in
            searchableItem(kind: item.kind, id: item.id, title: item.title,
                           contentDescription: String(localized: "Followed in AppleVis"), url: item.url)
        }
        guard !(saved.isEmpty && followed.isEmpty) else { return }
        CSSearchableIndex.default().indexSearchableItems(saved + followed)
    }

    private static func searchableItem(kind: ContentKind, id: String, title: String, contentDescription: String, url: String?) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: UTType.text)
        attributes.title = title
        attributes.contentDescription = contentDescription
        if let url, let contentURL = URL(string: url) { attributes.contentURL = contentURL }
        return CSSearchableItem(uniqueIdentifier: identifier(kind: kind, id: id), domainIdentifier: kind.rawValue, attributeSet: attributes)
    }
}
