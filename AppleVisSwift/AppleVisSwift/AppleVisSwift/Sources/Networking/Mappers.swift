import Foundation

// Maps Drupal JSON:API nodes into app models. Ported from src/services/api.ts's
// mapForum/mapPodcast/mapApp/mapBlog/mapComment/mapAppReview/mapResource/mapBug —
// field names and fallback logic mirror that file, which is the proven-working
// reference implementation against the live backend.

enum Mappers {
    private static let base = "https://www.applevis.com"

    // MARK: - Forums

    static func forum(_ node: JsonApiNode, included: [JsonApiNode] = []) -> ForumTopic {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue
            ?? userNode?.attributes["name"]?.stringValue ?? ""

        let taxId = node.relationshipId("taxonomy_forums")
        let taxTerm = taxId.flatMap { id in included.first { $0.id == id } }
        let category = taxTerm?.attributes["name"]?.stringValue ?? ""

        let commentInfo = a["comment_forum"]
        let replyCount = commentInfo?["comment_count"]?.intValue ?? 0
        let lastCommentTs = commentInfo?["last_comment_timestamp"]?.doubleValue ?? 0
        let lastActivity: Date = lastCommentTs > 0
            ? Date(timeIntervalSince1970: lastCommentTs)
            : node.changedDate

        let alias = a["path"]?.pathAlias
        let url = alias.map { "\(base)\($0)" } ?? "\(base)/node/\(node.id)"

        return ForumTopic(
            id: node.id,
            title: a["title"]?.stringValue ?? "",
            authorName: authorName,
            authorId: uidId ?? "",
            createdAt: node.createdDate,
            lastActivityAt: lastActivity,
            replyCount: replyCount,
            category: category,
            categoryId: taxId ?? "",
            url: url,
            isUnread: false,
            isFollowing: PersistenceStore.shared.isFollowed(id: node.id),
            isSaved: PersistenceStore.shared.isSaved(id: node.id)
        )
    }

    /// Maps a flat item from GET /api/v1/forums/recent (native REST, not JSON:API).
    /// Returns nil when the payload has no real uuid — a previous version
    /// fell back to `UUID().uuidString`, fabricating a random id that looks
    /// like a normal row but can never resolve server-side. Tapping it called
    /// `topicDetail(id:)` with that fake id and Drupal's JSON:API route
    /// rejected the malformed/nonexistent UUID with a 400 ("Unexpected error
    /// (HTTP 400)"), intermittently and only for topics missing this field —
    /// better to silently drop the row than show one guaranteed to error.
    ///
    /// Validates actual UUID *format* (`UUID(uuidString:)`), not just
    /// non-emptiness — a first pass only checked for an empty string, but a
    /// real-world repro (a topic whose category also came back blank,
    /// implying its `url` field was empty/missing too — likely a generally
    /// sparse record) kept 400ing afterward, meaning the field can come back
    /// non-empty but still not a real UUID (e.g. the literal string "null").
    static func forumFromRecent(_ item: [String: JSONValue]) -> ForumTopic? {
        guard let uuidString = item["uuid"]?.stringValue, UUID(uuidString: uuidString) != nil else { return nil }
        let uuid = uuidString
        let lastTs = item["last_comment_timestamp"]?.doubleValue ?? 0
        let changed = item["changed"]?.doubleValue ?? 0
        let lastActivity: Date = lastTs > 0
            ? Date(timeIntervalSince1970: lastTs)
            : Date(timeIntervalSince1970: changed)
        let created = item["created"]?.doubleValue ?? 0
        let replyCount = item["comment_count"]?.intValue ?? 0
        let urlPath = item["url"]?.stringValue ?? ""
        // Confirmed via a live repro: /api/v1/forums/recent has returned an
        // item whose uuid actually belongs to an App Directory node, not a
        // forum topic — its url was the app's real /apps/... page (which is
        // why "Open in Browser" worked fine), but the app rendered it as a
        // topic (bare "topic", blank category from categoryFromForumURL)
        // and 400'd on open (node/forum/{uuid} doesn't resolve, since the
        // node's actual bundle isn't "forum"). Reject anything that isn't
        // genuinely a /forum/{category}/{slug} URL rather than show a
        // broken, erroring card for content that isn't a forum topic.
        guard isForumURL(urlPath) else { return nil }
        return ForumTopic(
            id: uuid,
            title: item["title"]?.stringValue ?? "",
            authorName: "",
            authorId: "",
            createdAt: created > 0 ? Date(timeIntervalSince1970: created) : .distantPast,
            lastActivityAt: lastActivity,
            replyCount: replyCount,
            category: categoryFromForumURL(urlPath),
            categoryId: "",
            url: urlPath,
            isUnread: false,
            isFollowing: PersistenceStore.shared.isFollowed(id: uuid),
            isSaved: PersistenceStore.shared.isSaved(id: uuid)
        )
    }

    private static func forumURLParts(_ urlString: String) -> [String]? {
        guard let url = URL(string: urlString) ?? URL(string: base + urlString) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0] == "forum" else { return nil }
        return parts
    }

    private static func isForumURL(_ urlString: String) -> Bool {
        forumURLParts(urlString) != nil
    }

    /// e.g. "/forum/apple-beta-releases/some-topic" -> "Apple Beta Releases"
    private static func categoryFromForumURL(_ urlString: String) -> String {
        guard let parts = forumURLParts(urlString) else { return "" }
        return parts[1]
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    static func forumReply(_ node: JsonApiNode, included: [JsonApiNode] = []) -> ForumReply {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue
            ?? userNode?.attributes["name"]?.stringValue
            ?? a["name"]?.stringValue ?? ""
        return ForumReply(
            id: node.id,
            subject: a["subject"]?.stringValue ?? "",
            authorName: authorName,
            authorId: uidId ?? "",
            body: a["comment_body"]?.richTextValue ?? "",
            createdAt: node.createdDate,
            loveCount: 0,
            isNew: false
        )
    }

    // MARK: - Podcasts

    static func podcast(_ node: JsonApiNode, included: [JsonApiNode] = []) -> PodcastEpisode {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue
            ?? userNode?.attributes["name"]?.stringValue ?? ""

        let fileId = node.relationshipId("field_podcast")
        let fileNode = fileId.flatMap { id in included.first { $0.id == id } }
        let rawUri = fileNode?.attributes["uri"]?["value"]?.stringValue
        let audioUrl = rawUri?.replacingOccurrences(of: "public://", with: "\(base)/sites/default/files/") ?? ""

        let transcriptUrl = a["field_transcript_url"]?.stringValue ?? a["field_vtt_url"]?.stringValue

        let chapterRefs = node.relationshipIds("field_chapters")
        let chapters: [Chapter] = chapterRefs
            .compactMap { id in included.first { $0.id == id } }
            .map { n -> Chapter in
                Chapter(
                    id: n.id,
                    title: n.attributes["title"]?.stringValue ?? n.attributes["field_title"]?.stringValue ?? "",
                    startTime: n.attributes["field_start_time"]?.doubleValue ?? n.attributes["field_time"]?.doubleValue ?? 0,
                    endTime: 0
                )
            }
            .filter { !$0.title.isEmpty }
            .sorted { $0.startTime < $1.startTime }

        let tagRefs = node.relationshipIds("taxonomy_vocabulary_15")
        let tags: [PodcastTag] = tagRefs
            .compactMap { id in included.first { $0.id == id } }
            .filter { $0.type.hasPrefix("taxonomy_term") }
            .compactMap { n -> PodcastTag? in
                let name = n.attributes["name"]?.stringValue ?? ""
                let tid = n.attributes["drupal_internal__tid"]?.intValue ?? 0
                guard !name.isEmpty, tid > 0 else { return nil }
                return PodcastTag(id: n.id, name: name, tid: tid, count: 0)
            }

        let alias = a["path"]?.pathAlias
        let url = alias.map { "\(base)\($0)" } ?? "\(base)/node/\(node.id)"

        return PodcastEpisode(
            id: node.id,
            title: a["title"]?.stringValue ?? "",
            showTitle: "AppleVis Podcast",
            audioUrl: audioUrl,
            duration: 0,
            publishedAt: node.createdDate,
            lastActivityAt: node.changedDate,
            description: a["body"]?.richTextValue ?? "",
            artworkUrl: nil,
            transcriptUrl: (transcriptUrl?.isEmpty == false) ? transcriptUrl : nil,
            chapters: chapters,
            tags: tags,
            commentCount: a["comment_node_podcast"]?["comment_count"]?.intValue ?? 0,
            authorName: authorName,
            url: url,
            isSaved: PersistenceStore.shared.isSaved(id: node.id),
            isDownloaded: false,
            downloadProgress: nil
        )
    }

    private static func fileURI(_ drupalURI: String) -> String {
        drupalURI.replacingOccurrences(of: "public://", with: "\(base)/sites/default/files/")
    }

    // MARK: - Apps

    private static let appCategoryRelationshipCandidates = [
        "field_category", "field_app_category", "field_app_categories",
        "field_directory_category", "field_ios_app_category",
        "field_app_store_category", "taxonomy_app_category", "taxonomy_categories",
    ]

    private static func relatedTermName(_ node: JsonApiNode, included: [JsonApiNode], candidates: [String]) -> String {
        for fieldName in candidates {
            let refs = node.relationshipIds(fieldName)
            for ref in refs {
                if let term = included.first(where: { $0.id == ref }),
                   let name = term.attributes["name"]?.stringValue, !name.isEmpty {
                    return name
                }
            }
        }
        return ""
    }

    static func app(_ node: JsonApiNode, included: [JsonApiNode] = []) -> AppListing {
        let a = node.attributes
        let deviceUsed = a["field_device_used"]
        let supportedDevices: [String] = {
            if let arr = deviceUsed?.arrayValue { return arr.compactMap { $0.stringValue } }
            if let s = deviceUsed?.stringValue { return [s] }
            return []
        }()

        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let submittedBy = userNode?.attributes["display_name"]?.stringValue ?? userNode?.attributes["name"]?.stringValue ?? ""

        let category = relatedTermName(node, included: included, candidates: appCategoryRelationshipCandidates)
        let commentInfo = a["comment_node_ios_app_directory"]
        let alias = a["path"]?.pathAlias
        let url = alias.map { "\(base)\($0)" } ?? "\(base)/node/\(node.id)"
        let appStoreUrl = a["field_link2"]?["uri"]?.stringValue ?? a["field_link3"]?["uri"]?.stringValue ?? ""
        let lastCommentTs = commentInfo?["last_comment_timestamp"]?.doubleValue ?? 0

        return AppListing(
            id: node.id,
            name: a["title"]?.stringValue ?? "",
            developer: "",
            platform: .ios,
            category: category,
            categoryId: "",
            reviewCount: commentInfo?["comment_count"]?.intValue ?? 0,
            lastUpdatedAt: node.changedDate,
            lastActivityAt: lastCommentTs > 0 ? Date(timeIntervalSince1970: lastCommentTs) : node.changedDate,
            createdAt: node.createdDate,
            submittedBy: submittedBy,
            submitterUid: uidId ?? "",
            appStoreUrl: appStoreUrl.isEmpty ? nil : appStoreUrl,
            iconUrl: nil,
            price: a["field_cost"]?.stringValue ?? "",
            supportedDevices: supportedDevices,
            voiceOverPerformance: a["field_voiceover"]?.stringValue,
            summary: a["body"]?.richTextSummary ?? a["body"]?.richTextValue ?? "",
            url: url,
            isSaved: PersistenceStore.shared.isSaved(id: node.id)
        )
    }

    static func appReview(_ node: JsonApiNode, included: [JsonApiNode] = []) -> AppReview {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue
            ?? userNode?.attributes["name"]?.stringValue
            ?? a["name"]?.stringValue ?? ""
        return AppReview(
            id: node.id,
            subject: a["subject"]?.stringValue ?? "Review",
            authorName: authorName,
            authorId: uidId ?? "",
            rating: nil,
            body: a["comment_body"]?.richTextValue ?? "",
            createdAt: node.createdDate
        )
    }

    // MARK: - Blogs

    static func blog(_ node: JsonApiNode, included: [JsonApiNode] = []) -> BlogPost {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue ?? userNode?.attributes["name"]?.stringValue ?? ""
        let alias = a["path"]?.pathAlias
        let url = alias.map { "\(base)\($0)" } ?? "\(base)/node/\(node.id)"
        return BlogPost(
            id: node.id,
            title: a["title"]?.stringValue ?? "",
            authorName: authorName,
            authorId: uidId ?? "",
            publishedAt: node.createdDate,
            lastActivityAt: node.changedDate,
            summary: a["body"]?.richTextSummary ?? a["body"]?.richTextValue ?? "",
            commentCount: a["comment_node_blog2"]?["comment_count"]?.intValue ?? 0,
            url: url,
            isSaved: PersistenceStore.shared.isSaved(id: node.id)
        )
    }

    // MARK: - Generic comments (resource / blog / podcast)

    static func genericComment(_ node: JsonApiNode, included: [JsonApiNode] = []) -> (authorName: String, authorId: String, subject: String, body: String, createdAt: Date) {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue
            ?? userNode?.attributes["name"]?.stringValue
            ?? a["name"]?.stringValue ?? ""
        return (authorName, uidId ?? "", a["subject"]?.stringValue ?? "", a["comment_body"]?.richTextValue ?? "", node.createdDate)
    }

    // MARK: - Resources / Guides

    static func resource(_ node: JsonApiNode, included: [JsonApiNode] = []) -> Resource {
        let a = node.attributes
        let uidId = node.relationshipId("uid")
        let userNode = uidId.flatMap { id in included.first { $0.id == id } }
        let authorName = userNode?.attributes["display_name"]?.stringValue
            ?? userNode?.attributes["name"]?.stringValue
            ?? a["field_author"]?.stringValue ?? ""

        let categoryRefs = node.relationshipIds("taxonomy_vocabulary_3")
        let categories = categoryRefs
            .compactMap { id in included.first { $0.id == id } }
            .filter { $0.type.hasPrefix("taxonomy_term") }
            .compactMap { $0.attributes["name"]?.stringValue }

        let alias = a["path"]?.pathAlias
        let url = alias.map { "\(base)\($0)" } ?? "\(base)/node/\(node.id)"

        return Resource(
            id: node.id,
            title: a["title"]?.stringValue ?? "",
            kind: .guide,
            authorName: authorName,
            authorId: uidId ?? "",
            categories: categories,
            summary: a["body"]?.richTextSummary ?? a["body"]?.richTextValue ?? "",
            createdAt: node.createdDate,
            updatedAt: node.changedDate,
            commentCount: a["comment_node_guides"]?["comment_count"]?.intValue ?? 0,
            url: url,
            isSaved: PersistenceStore.shared.isSaved(id: node.id)
        )
    }

    // MARK: - Bug reports

    static func bugVersionLabel(_ raw: String, platform: BugPlatform) -> String {
        guard !raw.isEmpty, raw != "unknown", raw != "0" else { return "" }
        if raw.allSatisfy(\.isNumber) { return "" }
        if raw.hasPrefix("ios_ipados_") {
            return "iOS/iPadOS " + raw.replacingOccurrences(of: "ios_ipados_", with: "").replacingOccurrences(of: "_", with: ".")
        }
        if raw.hasPrefix("macos_") {
            let parts = raw.replacingOccurrences(of: "macos_", with: "").split(separator: "_").map(String.init)
            guard let first = parts.first else { return raw }
            let codeName = first.prefix(1).uppercased() + first.dropFirst()
            let version = parts.dropFirst().joined(separator: ".")
            return version.isEmpty ? "macOS \(codeName)" : "macOS \(codeName) \(version)"
        }
        return raw
    }

    static func bug(_ node: JsonApiNode, platform: BugPlatform) -> BugReport {
        let a = node.attributes
        let commentKey = platform == .ios ? "comment_node_ios_bug_report" : "comment_node_os_x_bug_report"
        let firstSeenRaw = (platform == .ios ? a["field_bug_first_noticed"] : a["field_bug_first_encountered"])?.stringValue ?? ""
        let fixedInRaw = (platform == .ios ? a["field_fixed_in"] : a["field_bug_fixed_in"])?.stringValue ?? ""
        let statusInt = a["field_status"]?.intValue ?? 0
        let severityInt = a["field_severity"]?.intValue ?? 0
        let fixedIn = fixedInRaw.isEmpty ? nil : bugVersionLabel(fixedInRaw, platform: platform)
        let alias = a["path"]?.pathAlias
        let summary = HTMLText.plainText(fromHTML: a["body"]?.richTextSummary ?? a["body"]?.richTextValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return BugReport(
            id: node.id,
            title: a["title"]?.stringValue ?? "",
            platform: platform,
            status: statusInt == 1 ? .active : .fixed,
            severity: severityInt == 2 ? .high : (severityInt == 1 ? .medium : .low),
            firstSeen: bugVersionLabel(firstSeenRaw, platform: platform).isEmpty ? nil : bugVersionLabel(firstSeenRaw, platform: platform),
            fixedIn: (fixedIn?.isEmpty ?? true) ? nil : fixedIn,
            feedbackId: a["field_apple_feedback_"]?.stringValue,
            commentCount: a[commentKey]?["comment_count"]?.intValue ?? 0,
            createdAt: node.createdDate,
            changedAt: node.changedDate,
            summary: summary,
            url: alias.map { "\(base)\($0)" } ?? "\(base)/bugs"
        )
    }

    static func bugDetail(_ node: JsonApiNode, platform: BugPlatform) -> BugReportDetail {
        let a = node.attributes
        let base = bug(node, platform: platform)
        let howOftenInt = a["field_how_often_the_bug_occurs"]?.intValue ?? 0
        let howOften: String = howOftenInt == 2 ? "always" : (howOftenInt == 1 ? "sometimes" : "rarely")
        return BugReportDetail(
            id: base.id,
            title: base.title,
            platform: base.platform,
            status: base.status,
            severity: base.severity,
            firstSeen: base.firstSeen,
            fixedIn: base.fixedIn,
            feedbackId: base.feedbackId,
            body: HTMLText.plainText(fromHTML: a["body"]?.richTextValue ?? ""),
            stepsToReproduce: a["field_steps_to_reproduce"]?.richTextValue.map { HTMLText.plainText(fromHTML: $0) },
            workaround: a["field_workaround"]?.richTextValue.map { HTMLText.plainText(fromHTML: $0) },
            device: a["field_device_s_bug_has_been_enco"]?.stringValue,
            howOften: howOften,
            commentCount: base.commentCount,
            createdAt: base.createdAt,
            changedAt: base.changedAt,
            url: base.url,
            comments: []
        )
    }
}
