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

    static func index(_ topic: ForumTopic) {
        index(kind: .forumTopic, id: topic.id, title: topic.title, contentDescription: "\(topic.category) · \(topic.replyCount) replies", url: topic.url)
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
}
