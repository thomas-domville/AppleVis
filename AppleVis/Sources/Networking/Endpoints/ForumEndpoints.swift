import Foundation

extension APIClient {
    var forums: ForumEndpoints { ForumEndpoints(client: self) }
}

struct ForumEndpoints {
    let client: APIClient

    /// Non-Apple forum taxonomy term IDs, confirmed via live probe of
    /// /jsonapi/taxonomy_term/forums (see src/services/api.ts FORUM_NON_APPLE_TIDS).
    private static let nonAppleTids = [265, 266, 267, 269]

    /// Sorted by last-comment activity via the native `/api/v1/forums/recent`
    /// endpoint — matches the website's own sort order (JSON:API `-changed`
    /// sort does not, since it doesn't account for new comments on old topics).
    ///
    /// `includePinned` (Forums only) adds every topic pinned on the website
    /// to the top of the first page, even quiet ones this activity-sorted
    /// feed wouldn't reach. Asked fresh each time, so a topic unpinned on
    /// the website drops back into its place on the next refresh.
    func recent(page: Int = 0, appleOnly: Bool = false, includePinned: Bool = false, forceRefresh: Bool = false) async throws -> [ForumTopic] {
        let pinnedKey = includePinned && page == 0 ? ":pinned" : ""
        return try await fetchWithCache(group: .forums, key: "forums:list:\(appleOnly):\(page)\(pinnedKey)", forceRefresh: forceRefresh) {
            var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
            if appleOnly {
                queryItems += Self.nonAppleTids.map { URLQueryItem(name: "apple_only[]", value: "\($0)") }
            }
            let raw: JSONValue = try await client.get("forums/recent", queryItems: queryItems)
            let items = raw.arrayValue ?? []
            let topics = items.compactMap { $0.objectValue }.compactMap { Mappers.forumFromRecent($0) }
            // Pinned first among the topics this page contains. The server
            // still pages by activity, so older pins can arrive on later pages.
            let ordered = topics.enumerated()
                .sorted { $0.element.isPinned != $1.element.isPinned ? $0.element.isPinned : $0.offset < $1.offset }
                .map(\.element)
            // If the pinned list can't be fetched, the page still loads.
            guard page == 0, includePinned,
                  let pinned = try? await pinnedTopics(appleOnly: appleOnly), !pinned.isEmpty else { return ordered }
            let pinnedIds = Set(pinned.map(\.id))
            return pinned + ordered.filter { !pinnedIds.contains($0.id) }
        }
    }

    /// Every forum topic pinned on the website right now, newest first.
    /// The website's activity-sorted list can't put quiet pinned topics on
    /// its first page, so they're asked for directly (checked live,
    /// 2026-10-05). Nothing pinned is an empty list.
    func pinnedTopics(appleOnly: Bool) async throws -> [ForumTopic] {
        let response = try await client.jsonAPIList(
            "node/forum",
            query: ["filter[sticky]": "1", "filter[status]": "1", "include": "uid,taxonomy_forums",
                    "sort": "-changed", "page[limit]": "20"]
        )
        let included = response.included ?? []
        return response.data.compactMap { node in
            if appleOnly,
               let termId = node.relationshipId("taxonomy_forums"),
               let tid = included.first(where: { $0.id == termId })?.attributes["drupal_internal__tid"]?.intValue,
               Self.nonAppleTids.contains(tid) {
                return nil
            }
            var topic = Mappers.forum(node, included: included)
            topic.isPinned = true
            return topic
        }
    }

    /// Server-side category-filtered listing — used instead of client-side
    /// filtering `recent()`'s global feed once a specific category is
    /// selected. `recent()` is a "recent activity" feed, not an exhaustive
    /// archive; a sparse category's (e.g. "Android") matches can sit
    /// arbitrarily deep in its page history, so ForumsBrowseView's auto-
    /// topup (`loadMoreUntilEnoughOrCap`) could burn through its whole
    /// fetch-attempt cap wading through mostly-irrelevant recent topics
    /// without ever finding enough of that one category, even when Drupal
    /// actually has plenty more of it further back than "recent" reaches.
    /// Reported directly: an already-existing topup mechanism still wasn't
    /// enough for a sparse category. Filters `taxonomy_forums` the same way
    /// `field_category_watch` is filtered in
    /// `AppEndpoints.jsonAPIWatchCategoryListing` — same JSON:API pattern
    /// already confirmed live for an equivalent taxonomy-reference field,
    /// not separately re-verified against this specific relationship.
    func categoryListing(tid: Int, page: Int, limit: Int = APIPaging.pageSize, forceRefresh: Bool = false) async throws -> PagedListResult<ForumTopic> {
        try await fetchWithCache(group: .forums, key: "forums:category:\(tid):\(page)", forceRefresh: forceRefresh) {
            let response = try await client.jsonAPIList(
                "node/forum",
                query: [
                    "filter[taxonomy_forums.drupal_internal__tid]": "\(tid)",
                    "sort": "-changed",
                    "page[limit]": "\(limit)",
                    "page[offset]": "\(page * limit)",
                    "include": "uid,taxonomy_forums",
                ]
            )
            let items = response.data.map { Mappers.forum($0, included: response.included ?? []) }
            return PagedListResult(items: items, hasMore: response.hasNextPage)
        }
    }

    func categories() async throws -> [ForumCategory] {
        let response = try await client.jsonAPIList(
            "taxonomy_term/forums",
            query: ["fields[taxonomy_term--forums]": "name,drupal_internal__tid", "sort": "name"]
        )
        return response.data.compactMap { node -> ForumCategory? in
            let name = node.attributes["name"]?.stringValue ?? ""
            let tid = node.attributes["drupal_internal__tid"]?.intValue ?? 0
            guard !name.isEmpty, tid > 0 else { return nil }
            return ForumCategory(id: node.id, name: name, tid: tid, topicCount: 0)
        }
    }

    func topic(id: String) async throws -> ForumTopic {
        let response = try await client.remapping400ToNotFound {
            try await client.jsonAPISingle("node/forum/\(id)", query: ["include": "uid,taxonomy_forums"])
        }
        return Mappers.forum(response.data, included: response.included ?? [])
    }

    func topicDetail(id: String, forceRefresh: Bool = false) async throws -> ForumTopicDetail {
        try await fetchWithCache(group: .forums, key: "forums:detail:\(id)", forceRefresh: forceRefresh) {
            async let topicRes = client.jsonAPISingle("node/forum/\(id)", query: ["include": "uid,taxonomy_forums"])
            async let commentsRes = client.jsonAPIList(
                "comment/comment_forum",
                query: ["filter[entity_id.id]": id, "sort": "created", "page[limit]": "100", "include": "uid"]
            )

            let topicResponse: JsonApiSingleResponse
            do {
                topicResponse = try await topicRes
            } catch APIError.unknown(400) {
                throw APIError.notFound
            }
            let node = topicResponse.data
            let included = topicResponse.included ?? []
            let topic = Mappers.forum(node, included: included)
            let body = node.attributes["body"]?.richTextValue ?? ""
            let rawBody = node.attributes["body"]?.rawTextValue ?? ""
            let bodyFormat = node.attributes["body"]?.textFormat ?? drupalDefaultTextFormat
            let alias = node.attributes["path"]?.pathAlias
            let url = alias.map { "https://www.applevis.com\($0)" } ?? "https://www.applevis.com/node/\(node.id)"

            // Previously `try?`-swallowed: a comments-fetch failure (network
            // blip, timeout) looked identical to "genuinely zero comments,"
            // silently hiding the whole Community Discussion section (see
            // ForumTopicDetailView's `!detail.replies.isEmpty` guard) with no
            // error and no retry — and since nothing ever threw, this
            // half-broken result got cached by `fetchWithCache` as if it
            // were a complete success, so it could keep looking broken on
            // repeat visits too. Letting it propagate instead uses
            // `fetchWithCache`'s own fallback (last good cached copy, or a
            // proper retryable error) rather than bypassing it. Reported
            // directly: a topic showing the correct reply count on its card
            // had no Community Discussion section at all on its detail page.
            let commentsResponse = try await commentsRes
            let replies = commentsResponse.data.map { Mappers.forumReply($0, included: commentsResponse.included ?? []) }

            return ForumTopicDetail(
                id: topic.id,
                nid: node.attributes["drupal_internal__nid"]?.intValue ?? 0,
                title: topic.title,
                authorName: topic.authorName,
                authorId: topic.authorId,
                createdAt: topic.createdAt,
                lastActivityAt: topic.lastActivityAt,
                replyCount: topic.replyCount,
                viewCount: 0,
                category: topic.category,
                categoryId: topic.categoryId,
                body: body,
                rawBody: rawBody,
                bodyFormat: bodyFormat,
                url: url,
                isFollowing: false,
                isSaved: false,
                replies: replies,
                isPinned: topic.isPinned
            )
        }
    }

    /// Note: mirrors the RN reference implementation, which does not attach a
    /// category relationship on topic creation — Drupal appears to accept forum
    /// nodes without one. `categoryTid` is accepted for API-surface parity but
    /// currently unused in the request body.
    @discardableResult
    /// `categoryId` is the forum's own JSON:API id (`ForumCategory.id`).
    /// The chosen forum was never sent: the topic was created with no forum
    /// at all, so it never appeared in any forum or on Home, and the person
    /// was told nothing went wrong. Reported by a beta tester (2026-10-05).
    /// The relationship shape matches what the site returns for existing
    /// topics, checked live.
    ///
    /// `isPublished` is the site's own answer. A topic the site keeps for a
    /// moderator to approve comes back unpublished, and the app used to say
    /// "Topic posted" anyway.
    func submitTopic(title: String, body: String, categoryId: String, csrfToken: String) async throws -> (topic: ForumTopic, isPublished: Bool) {
        let response = try await client.jsonAPICreate(
            "node/forum",
            type: "node--forum",
            attributes: [
                "title": AnyEncodable(title),
                "body": AnyEncodable(RichTextValue(value: body, format: drupalDefaultTextFormat)),
            ],
            relationships: [
                "taxonomy_forums": JsonApiRelationshipRef(type: "taxonomy_term--forums", id: categoryId),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let isPublished = response.data.attributes["status"]?.boolValue ?? true
        return (Mappers.forum(response.data, included: response.included ?? []), isPublished)
    }

    /// `replyToCommentId` sets the real Drupal `pid` (parent comment)
    /// relationship — added alongside the site's own new "Reply" button
    /// (see `ForumReply.parentId`'s doc comment for the full story). Nil
    /// posts a plain top-level comment, same as before.
    @discardableResult
    func submitReply(topicId: String, body: String, csrfToken: String, subject: String = "Reply", replyToCommentId: String? = nil) async throws -> ForumReply {
        var relationships: [String: JsonApiRelationshipRef] = [
            "entity_id": JsonApiRelationshipRef(type: "node--forum", id: topicId),
            "comment_type": CommentBundle.forumTopic.commentTypeRelationship,
        ]
        if let replyToCommentId {
            relationships["pid"] = JsonApiRelationshipRef(type: "comment--comment_forum", id: replyToCommentId)
        }
        var attributes = CommentBundle.forumTopic.baseAttributes
        attributes["subject"] = AnyEncodable(subject)
        attributes["comment_body"] = AnyEncodable(RichTextValue(value: body, format: drupalDefaultTextFormat))
        let response = try await client.jsonAPICreate(
            "comment/comment_forum",
            type: "comment--comment_forum",
            attributes: attributes,
            relationships: relationships,
            headers: ["X-CSRF-Token": csrfToken]
        )
        return Mappers.forumReply(response.data, included: response.included ?? [])
    }

    /// Fetches the next page of replies for a topic (used by "Load more replies").
    func moreReplies(topicId: String, offset: Int) async throws -> [ForumReply] {
        let response = try await client.jsonAPIList(
            "comment/comment_forum",
            query: ["filter[entity_id.id]": topicId, "sort": "created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { Mappers.forumReply($0, included: response.included ?? []) }
    }

    func follow(nodeUuid: String, entityId: Int, token: String) async throws {
        try await client.flags.follow(nodeUuid: nodeUuid, nodeType: "node--forum", entityId: entityId, token: token)
    }

    func unfollow(nodeUuid: String, token: String) async throws {
        try await client.flags.unfollow(nodeUuid: nodeUuid, token: token)
    }
}

/// Shared Drupal rich-text field shape: `{ value, format }`.
struct RichTextValue: Encodable {
    let value: String
    let format: String
}
