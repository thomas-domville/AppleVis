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
    func recent(page: Int = 0, appleOnly: Bool = false) async throws -> [ForumTopic] {
        try await fetchWithCache(group: .forums, key: "forums:list:\(appleOnly):\(page)") {
            var queryItems = [URLQueryItem(name: "page", value: "\(page)")]
            if appleOnly {
                queryItems += Self.nonAppleTids.map { URLQueryItem(name: "apple_only[]", value: "\($0)") }
            }
            let raw: JSONValue = try await client.get("forums/recent", queryItems: queryItems)
            let items = raw.arrayValue ?? []
            return items.compactMap { $0.objectValue }.map(Mappers.forumFromRecent)
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
        let response = try await client.jsonAPISingle("node/forum/\(id)", query: ["include": "uid,taxonomy_forums"])
        return Mappers.forum(response.data, included: response.included ?? [])
    }

    func topicDetail(id: String) async throws -> ForumTopicDetail {
        try await fetchWithCache(group: .forums, key: "forums:detail:\(id)") {
            async let topicRes = client.jsonAPISingle("node/forum/\(id)", query: ["include": "uid,taxonomy_forums"])
            async let commentsRes = client.jsonAPIList(
                "comment/comment_forum",
                query: ["filter[entity_id.id]": id, "sort": "created", "page[limit]": "100", "include": "uid"]
            )

            let topicResponse = try await topicRes
            let node = topicResponse.data
            let included = topicResponse.included ?? []
            let topic = Mappers.forum(node, included: included)
            let body = node.attributes["body"]?.richTextValue ?? ""
            let alias = node.attributes["path"]?.pathAlias
            let url = alias.map { "https://www.applevis.com\($0)" } ?? "https://www.applevis.com/node/\(node.id)"

            let replies: [ForumReply]
            if let commentsResponse = try? await commentsRes {
                replies = commentsResponse.data.map { Mappers.forumReply($0, included: commentsResponse.included ?? []) }
            } else {
                replies = []
            }

            return ForumTopicDetail(
                id: topic.id,
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
                url: url,
                isFollowing: false,
                isSaved: false,
                replies: replies
            )
        }
    }

    /// Note: mirrors the RN reference implementation, which does not attach a
    /// category relationship on topic creation — Drupal appears to accept forum
    /// nodes without one. `categoryTid` is accepted for API-surface parity but
    /// currently unused in the request body.
    @discardableResult
    func submitTopic(title: String, body: String, categoryTid: Int, csrfToken: String) async throws -> ForumTopic {
        let response = try await client.jsonAPICreate(
            "node/forum",
            type: "node--forum",
            attributes: [
                "title": AnyEncodable(title),
                "body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        return Mappers.forum(response.data, included: response.included ?? [])
    }

    @discardableResult
    func submitReply(topicId: String, body: String, csrfToken: String, subject: String = "Reply") async throws -> ForumReply {
        let response = try await client.jsonAPICreate(
            "comment/comment_forum",
            type: "comment--comment_forum",
            attributes: [
                "subject": AnyEncodable(subject),
                "comment_body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--forum", id: topicId),
                "comment_type": JsonApiRelationshipRef(type: "comment_type--comment_type", id: "comment_forum"),
            ],
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

    func follow(nodeUuid: String, token: String) async throws {
        try await client.flags.follow(nodeUuid: nodeUuid, nodeType: "node--forum", token: token)
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
