import Foundation

// Resources, Blogs, Bug Reports, Search, Flags (follow-only — "save" is local-only, see PersistenceStore)

extension APIClient {
    var resources: ResourceEndpoints { ResourceEndpoints(client: self) }
    var blogs: BlogEndpoints { BlogEndpoints(client: self) }
    var bugReports: BugReportEndpoints { BugReportEndpoints(client: self) }
    var search: SearchEndpoints { SearchEndpoints(client: self) }
    var flags: FlagEndpoints { FlagEndpoints(client: self) }
}

// MARK: - Resources / Guides

struct ResourceEndpoints {
    let client: APIClient
    private static let pageSize = 20

    func list(page: Int = 0, categoryTids: [Int] = []) async throws -> PagedListResult<Resource> {
        let categoryKey = categoryTids.isEmpty ? "" : ":categories:\(categoryTids.sorted())"
        return try await fetchWithCache(group: .resources, key: "resources:list:\(page)\(categoryKey)") {
            var query: [String: String] = [
                "sort": "-changed", "include": "taxonomy_vocabulary_3,uid",
                "page[limit]": "\(Self.pageSize)", "page[offset]": "\(page * Self.pageSize)",
            ]
            if !categoryTids.isEmpty {
                query["filter[category][condition][path]"] = "taxonomy_vocabulary_3.drupal_internal__tid"
                query["filter[category][condition][operator]"] = "IN"
                for (i, tid) in categoryTids.enumerated() { query["filter[category][condition][value][\(i)]"] = "\(tid)" }
            }
            let response = try await client.jsonAPIList("node/guides", query: query)
            let items = response.data.map { Mappers.resource($0, included: response.included ?? []) }
            return PagedListResult(items: items, hasMore: response.hasNextPage)
        }
    }

    /// Fetches the guide with full body and its comments (bundle: comment_node_guides).
    func detail(id: String) async throws -> ResourceDetail {
        try await fetchWithCache(group: .resources, key: "resources:detail:\(id)") {
            async let resourceRes = client.jsonAPISingle("node/guides/\(id)", query: ["include": "uid"])
            async let commentsRes = client.jsonAPIList(
                "comment/comment_node_guides",
                query: ["filter[entity_id.id]": id, "sort": "created", "page[limit]": "100", "include": "uid"]
            )
            let response: JsonApiSingleResponse
            do {
                response = try await resourceRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = response.data
            let resource = Mappers.resource(node, included: response.included ?? [])
            let body = node.attributes["body"]?.richTextValue ?? ""

            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let commentsResponse = try await commentsRes
            let comments = commentsResponse.data.map { n in
                let c = Mappers.genericComment(n, included: commentsResponse.included ?? [])
                return ResourceComment(id: n.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
            }

            return ResourceDetail(
                id: resource.id, nid: node.attributes["drupal_internal__nid"]?.intValue ?? 0,
                title: resource.title, kind: resource.kind,
                authorName: resource.authorName, authorId: resource.authorId,
                categories: resource.categories, summary: resource.summary, body: body,
                createdAt: resource.createdAt, updatedAt: resource.updatedAt,
                commentCount: resource.commentCount, url: resource.url,
                comments: comments, isSaved: false
            )
        }
    }

    @discardableResult
    func submitComment(resourceId: String, body: String, csrfToken: String) async throws -> ResourceComment {
        let response = try await client.jsonAPICreate(
            "comment/comment_node_guides",
            type: "comment--comment_node_guides",
            attributes: [
                "subject": AnyEncodable("Comment"),
                "comment_body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--guides", id: resourceId),
                "comment_type": JsonApiRelationshipRef(type: "comment_type--comment_type", id: "comment_node_guides"),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let c = Mappers.genericComment(response.data, included: response.included ?? [])
        return ResourceComment(id: response.data.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
    }

    /// Fetches the next page of comments beyond the initial 100 (used by "Load more comments").
    func moreComments(resourceId: String, offset: Int) async throws -> [ResourceComment] {
        let response = try await client.jsonAPIList(
            "comment/comment_node_guides",
            query: ["filter[entity_id.id]": resourceId, "sort": "created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { n in
            let c = Mappers.genericComment(n, included: response.included ?? [])
            return ResourceComment(id: n.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
        }
    }
}

// MARK: - Blogs

struct BlogEndpoints {
    let client: APIClient
    private static let pageSize = 20
    /// Confirmed live Drupal content type for blog posts.
    private static let contentType = "blog2"

    func list(page: Int = 0) async throws -> PagedListResult<BlogPost> {
        try await fetchWithCache(group: .blogs, key: "blogs:list:\(page)") {
            let response = try await client.jsonAPIList(
                "node/\(Self.contentType)",
                query: ["sort": "-changed", "include": "uid", "page[limit]": "\(Self.pageSize)", "page[offset]": "\(page * Self.pageSize)"]
            )
            let items = response.data.map { Mappers.blog($0, included: response.included ?? []) }
            return PagedListResult(items: items, hasMore: response.hasNextPage)
        }
    }

    /// Fetches the blog post with full body and its comments (bundle: comment_node_blog2).
    func detail(id: String) async throws -> BlogPostDetail {
        try await fetchWithCache(group: .blogs, key: "blogs:detail:\(id)") {
            async let postRes = client.jsonAPISingle("node/\(Self.contentType)/\(id)", query: ["include": "uid"])
            async let commentsRes = client.jsonAPIList(
                "comment/comment_node_\(Self.contentType)",
                query: ["filter[entity_id.id]": id, "sort": "created", "page[limit]": "100", "include": "uid"]
            )
            let response: JsonApiSingleResponse
            do {
                response = try await postRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = response.data
            let post = Mappers.blog(node, included: response.included ?? [])
            let body = node.attributes["body"]?.richTextValue ?? ""

            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let commentsResponse = try await commentsRes
            let comments = commentsResponse.data.map { n in
                let c = Mappers.genericComment(n, included: commentsResponse.included ?? [])
                return BlogComment(id: n.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
            }

            return BlogPostDetail(
                id: post.id, nid: node.attributes["drupal_internal__nid"]?.intValue ?? 0,
                title: post.title, authorName: post.authorName, authorId: post.authorId,
                publishedAt: post.publishedAt, lastActivityAt: post.lastActivityAt, body: body,
                commentCount: post.commentCount, url: post.url, comments: comments, isSaved: false
            )
        }
    }

    @discardableResult
    func submitComment(blogId: String, body: String, csrfToken: String) async throws -> BlogComment {
        let response = try await client.jsonAPICreate(
            "comment/comment_node_\(Self.contentType)",
            type: "comment--comment_node_\(Self.contentType)",
            attributes: [
                "subject": AnyEncodable("Comment"),
                "comment_body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--\(Self.contentType)", id: blogId),
                "comment_type": JsonApiRelationshipRef(type: "comment_type--comment_type", id: "comment_node_\(Self.contentType)"),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let c = Mappers.genericComment(response.data, included: response.included ?? [])
        return BlogComment(id: response.data.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
    }

    func moreComments(blogId: String, offset: Int) async throws -> [BlogComment] {
        let response = try await client.jsonAPIList(
            "comment/comment_node_\(Self.contentType)",
            query: ["filter[entity_id.id]": blogId, "sort": "created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { n in
            let c = Mappers.genericComment(n, included: response.included ?? [])
            return BlogComment(id: n.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
        }
    }
}

// MARK: - Bug Reports
// Two confirmed content types: node--ios_bug_report and node--os_x_bug_report.

struct BugReportEndpoints {
    let client: APIClient
    private static let pageSize = 20

    private func nodeType(for platform: BugPlatform) -> String {
        platform == .ios ? "ios_bug_report" : "os_x_bug_report"
    }

    func list(page: Int = 0, platform: BugPlatform? = nil, status: BugStatus? = nil) async throws -> PagedListResult<BugReport> {
        let effectivePlatform = platform ?? .ios
        let key = "bugs:list:\(effectivePlatform.rawValue):\(status?.rawValue ?? "all"):\(page)"
        return try await fetchWithCache(group: .bugs, key: key) {
            var query: [String: String] = [
                "sort": "-changed", "page[limit]": "\(Self.pageSize)", "page[offset]": "\(page * Self.pageSize)",
            ]
            // The REST filter is binary (active-only vs all); anything other than
            // "active" maps to "all" (there is no server-side "fixed" filter).
            if status == .active { query["filter[field_status]"] = "1" }
            let response = try await client.jsonAPIList("node/\(nodeType(for: effectivePlatform))", query: query)
            let items = response.data.map { Mappers.bug($0, platform: effectivePlatform) }
            return PagedListResult(items: items, hasMore: response.hasNextPage)
        }
    }

    /// The current screen doesn't carry platform context to the detail view,
    /// so this tries `ios_bug_report` first and falls back to `os_x_bug_report`.
    func detail(id: String) async throws -> BugReportDetail {
        if let ios = try? await detail(platform: .ios, id: id) { return ios }
        return try await detail(platform: .macos, id: id)
    }

    func detail(platform: BugPlatform, id: String) async throws -> BugReportDetail {
        try await fetchWithCache(group: .bugs, key: "bugs:detail:\(platform.rawValue):\(id)") {
            async let nodeRes = client.jsonAPISingle("node/\(nodeType(for: platform))/\(id)")
            async let commentsRes = client.jsonAPIList(
                "comment/\(commentBundle(for: platform))",
                query: ["filter[entity_id.id]": id, "sort": "created", "page[limit]": "100", "include": "uid"]
            )
            let response: JsonApiSingleResponse
            do {
                response = try await nodeRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            var detail = Mappers.bugDetail(response.data, platform: platform)
            // See ForumEndpoints.topicDetail's identical fix for the full
            // reasoning — a `try?`-swallowed comments failure previously
            // looked identical to "genuinely zero comments" and got cached
            // as a false success.
            let commentsResponse = try await commentsRes
            detail.comments = commentsResponse.data.map { n in
                let c = Mappers.genericComment(n, included: commentsResponse.included ?? [])
                return BugComment(id: n.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
            }
            return detail
        }
    }

    /// Fetches the next page of comments beyond the initial 100 (used by "Load more comments").
    func moreComments(platform: BugPlatform, bugId: String, offset: Int) async throws -> [BugComment] {
        let response = try await client.jsonAPIList(
            "comment/\(commentBundle(for: platform))",
            query: ["filter[entity_id.id]": bugId, "sort": "created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { n in
            let c = Mappers.genericComment(n, included: response.included ?? [])
            return BugComment(id: n.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
        }
    }

    /// Submits a new bug report comment — previously bug comments were
    /// read-only (fetched and displayed, but with no way to post one),
    /// unlike every other content type's comment thread.
    @discardableResult
    func submitComment(platform: BugPlatform, bugId: String, body: String, csrfToken: String) async throws -> BugComment {
        let bundle = commentBundle(for: platform)
        let response = try await client.jsonAPICreate(
            "comment/\(bundle)",
            type: "comment--\(bundle)",
            attributes: [
                "subject": AnyEncodable("Comment"),
                "comment_body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--\(nodeType(for: platform))", id: bugId),
                "comment_type": JsonApiRelationshipRef(type: "comment_type--comment_type", id: bundle),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let c = Mappers.genericComment(response.data, included: response.included ?? [])
        return BugComment(id: response.data.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
    }

    private func commentBundle(for platform: BugPlatform) -> String {
        platform == .ios ? "comment_node_ios_bug_report" : "comment_node_os_x_bug_report"
    }
}

// MARK: - Search
// Full-text search against the Solr site index (index/solr_site_index),
// scoped to one content type per request via filter[type] — the endpoint
// doesn't support comma-joined types in a single call. Same node--* resource
// types and attributes/relationships as the direct node endpoints, so the
// existing Mappers just work; this replaces the previous per-category
// title-CONTAINS fan-out (searched only titles, never body text) with real
// full-text relevance search across each category's actual content.

struct SearchEndpoints {
    let client: APIClient
    private static let solrIndexPath = "index/solr_site_index"

    func query(_ text: String) async throws -> SearchResults {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResults(forums: [], apps: [], guides: [], blogs: [], podcasts: [], bugs: []) }

        async let forumsRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "forum", "include": "uid,taxonomy_forums", "page[limit]": "10"]
        )
        async let appsRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "ios_app_directory", "include": "uid", "page[limit]": "10"]
        )
        async let guidesRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "guides", "page[limit]": "10"]
        )
        async let blogsRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "blog2", "include": "uid", "page[limit]": "10"]
        )
        async let podcastsRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "podcast", "include": "field_podcast,uid,taxonomy_vocabulary_15", "page[limit]": "10"]
        )
        async let iosBugsRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "ios_bug_report", "page[limit]": "10"]
        )
        async let macBugsRes = client.jsonAPIList(
            Self.solrIndexPath,
            query: ["filter[fulltext]": trimmed, "filter[type]": "os_x_bug_report", "page[limit]": "10"]
        )

        var failed: [String] = []

        let forumsResult = try? await forumsRes
        if forumsResult == nil { failed.append("Forums") }
        let appsResult = try? await appsRes
        if appsResult == nil { failed.append("Apps") }
        let guidesResult = try? await guidesRes
        if guidesResult == nil { failed.append("Guides") }
        let blogsResult = try? await blogsRes
        if blogsResult == nil { failed.append("Blogs") }
        let podcastsResult = try? await podcastsRes
        if podcastsResult == nil { failed.append("Podcasts") }
        let iosBugsResult = try? await iosBugsRes
        let macBugsResult = try? await macBugsRes
        if iosBugsResult == nil && macBugsResult == nil { failed.append("Bug Reports") }

        let forums = forumsResult.map { r in r.data.map { Mappers.forum($0, included: r.included ?? []) } } ?? []
        let apps = appsResult.map { r in r.data.map { Mappers.app($0, included: r.included ?? []) } } ?? []
        let guides = guidesResult.map { r in r.data.map { Mappers.resource($0, included: r.included ?? []) } } ?? []
        let blogs = blogsResult.map { r in r.data.map { Mappers.blog($0, included: r.included ?? []) } } ?? []
        let podcasts = podcastsResult.map { r in r.data.map { Mappers.podcast($0, included: r.included ?? []) } } ?? []
        let iosBugs = iosBugsResult.map { r in r.data.map { Mappers.bug($0, platform: .ios) } } ?? []
        let macBugs = macBugsResult.map { r in r.data.map { Mappers.bug($0, platform: .macos) } } ?? []

        return SearchResults(
            forums: forums, apps: apps, guides: guides, blogs: blogs, podcasts: podcasts, bugs: iosBugs + macBugs,
            failedCategories: failed
        )
    }
}

struct SearchResults {
    let forums: [ForumTopic]
    let apps: [AppListing]
    let guides: [Resource]
    let blogs: [BlogPost]
    let podcasts: [PodcastEpisode]
    let bugs: [BugReport]
    /// Display names of categories whose request failed — lets the UI tell
    /// "search failed for some sources" apart from "genuinely zero
    /// matches," which previously looked identical: every per-category
    /// fetch already swallowed its own errors into an empty array with no
    /// signal anywhere that anything had gone wrong.
    var failedCategories: [String] = []
}

// MARK: - Flags (follow any content — "save" has no server counterpart, see PersistenceStore)

struct FlagEndpoints {
    let client: APIClient

    /// Flag machine name confirmed live: subscribe_node.
    func follow(nodeUuid: String, nodeType: String, token: String) async throws {
        _ = try await client.jsonAPICreate(
            "flagging/subscribe_node",
            type: "flagging--subscribe_node",
            relationships: ["flagged_entity": JsonApiRelationshipRef(type: nodeType, id: nodeUuid)],
            headers: ["X-CSRF-Token": token]
        )
    }

    /// Every item this person follows — confirmed against the site's own
    /// `/user/{uid}/message-subscribe` ("Subscriptions") page: same
    /// `subscribe_node` flag this app's Follow feature already uses, just
    /// labeled "Subscribe/Unsubscribe" there instead of "Follow/Unfollow."
    /// Like `recommendedApps`, this has to be a real server fetch —
    /// `PersistenceStore.followedItems()` only ever knew about follows made
    /// inside this app, so anyone who followed something on the website
    /// first saw nothing here.
    func followedItems(uid: String, csrfToken: String) async throws -> [FollowedItem] {
        let response = try await client.jsonAPIList(
            "flagging/subscribe_node",
            query: ["filter[uid.id]": uid, "include": "flagged_entity", "sort": "-created"],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let included = response.included ?? []
        return response.data.compactMap { flagging in
            guard let entityId = flagging.relationshipId("flagged_entity"),
                  let node = included.first(where: { $0.id == entityId }),
                  let kind = ContentKind(nodeType: node.type) else { return nil }
            return FollowedItem(
                id: entityId,
                kind: kind,
                nodeType: node.type,
                title: node.attributes["title"]?.stringValue ?? "",
                followedAt: flagging.createdDate,
                lastActivityAt: node.changedDate,
                url: (node.attributes["path"]?.pathAlias).map { "https://www.applevis.com\($0)" } ?? ""
            )
        }
    }

    /// Unfollow requires resolving the flagging entity's own id first, then deleting it.
    func unfollow(nodeUuid: String, token: String) async throws {
        let list = try await client.jsonAPIList(
            "flagging/subscribe_node",
            query: ["filter[flagged_entity.id]": nodeUuid],
            headers: ["X-CSRF-Token": token]
        )
        guard let flagging = list.data.first else { return }
        try await client.jsonAPIDelete("flagging/subscribe_node/\(flagging.id)", headers: ["X-CSRF-Token": token])
    }

    /// "Recommend This App" — confirmed live against the site's own
    /// `/user/{uid}/recommendations` page and its `flag-recommend` unflag
    /// links: the flag machine name is `recommend`, same Flag module every
    /// other flag on this site (including `subscribe_node` above) already
    /// goes through, so it's exposed via JSON:API the identical way.
    func recommend(nodeUuid: String, nodeType: String, token: String) async throws {
        _ = try await client.jsonAPICreate(
            "flagging/recommend",
            type: "flagging--recommend",
            relationships: ["flagged_entity": JsonApiRelationshipRef(type: nodeType, id: nodeUuid)],
            headers: ["X-CSRF-Token": token]
        )
    }

    func unrecommend(nodeUuid: String, token: String) async throws {
        let list = try await client.jsonAPIList(
            "flagging/recommend",
            query: ["filter[flagged_entity.id]": nodeUuid],
            headers: ["X-CSRF-Token": token]
        )
        guard let flagging = list.data.first else { return }
        try await client.jsonAPIDelete("flagging/recommend/\(flagging.id)", headers: ["X-CSRF-Token": token])
    }

    /// Every app this person has recommended — unlike Follow/Save (tracked
    /// purely on-device, see `PersistenceStore`), this has to be a real
    /// server fetch: someone's recommendation history very likely predates
    /// ever installing this app (confirmed directly — the reference account
    /// checked against has recommendations dating back to 2019), so a
    /// local-only cache would show nothing for any existing member.
    func recommendedApps(uid: String, csrfToken: String) async throws -> [RecommendedApp] {
        let response = try await client.jsonAPIList(
            "flagging/recommend",
            query: ["filter[uid.id]": uid, "include": "flagged_entity", "sort": "-created"],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let included = response.included ?? []
        return response.data.compactMap { flagging in
            guard let entityId = flagging.relationshipId("flagged_entity"),
                  let node = included.first(where: { $0.id == entityId }) else { return nil }
            return RecommendedApp(
                id: entityId,
                title: node.attributes["title"]?.stringValue ?? "",
                platformLabel: RecommendedApp.platformLabel(forNodeType: node.type),
                recommendedAt: flagging.createdDate,
                url: (node.attributes["path"]?.pathAlias).map { "https://www.applevis.com\($0)" }
            )
        }
    }

    /// The "Recommendations" widget every app page shows — a count plus a
    /// "most recently recommended by" credit. Confirmed live against the
    /// Office 365 app page's own `view-recommendations-count` block. No
    /// CSRF/auth needed — this is public info shown to signed-out visitors
    /// on the website too. `page[limit]` caps at a generous 100 rather than
    /// paginating fully, matching this codebase's existing convention for
    /// "fetch everything reasonable" — the count could undercount for an
    /// app with more than 100 recommendations, an edge case not worth the
    /// extra pagination complexity here.
    func recommendationSummary(appUuid: String) async throws -> RecommendationSummary {
        let response = try await client.jsonAPIList(
            "flagging/recommend",
            query: ["filter[flagged_entity.id]": appUuid, "include": "uid", "sort": "-created", "page[limit]": "100"]
        )
        let included = response.included ?? []
        let mostRecent = response.data.first
        let recommenderName = mostRecent
            .flatMap { $0.relationshipId("uid") }
            .flatMap { recommenderId in included.first(where: { $0.id == recommenderId }) }
            .flatMap { $0.attributes["display_name"]?.stringValue ?? $0.attributes["name"]?.stringValue }
        return RecommendationSummary(
            count: response.data.count,
            mostRecentRecommenderName: recommenderName,
            mostRecentDate: mostRecent?.createdDate
        )
    }
}

/// The public "Recommendations" widget on an app page — a count plus who
/// most recently recommended it, mirroring the site's own block exactly.
struct RecommendationSummary {
    let count: Int
    let mostRecentRecommenderName: String?
    let mostRecentDate: Date?
}

/// A single row of "Apps I've Recommended" — deliberately lighter than the
/// full per-platform `AppListing`/`TvAppListing`/etc. models, since the
/// Recommendations list only ever needs a title, platform, date, and a link
/// to open the real app page, not every detail field those carry.
struct RecommendedApp: Identifiable {
    let id: String
    let title: String
    let platformLabel: String
    let recommendedAt: Date
    let url: String?

    static func platformLabel(forNodeType type: String) -> String {
        switch type {
        case "node--ios_app_directory":  return "iOS and iPadOS App Directory"
        case "node--tv_directory":       return "Apple TV App Directory"
        case "node--watch_directory":    return "Apple Watch App Directory"
        case "node--mac_app_directory":  return "Mac App Directory"
        default:                         return "App Directory"
        }
    }
}
