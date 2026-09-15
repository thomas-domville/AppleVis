import Foundation

extension APIClient {
    var podcasts: PodcastEndpoints { PodcastEndpoints(client: self) }
}

struct PodcastEndpoints {
    let client: APIClient

    private static let pageSize = 20

    func episodes(page: Int = 0, sort: PodcastSort = .recent, tagTid: Int? = nil) async throws -> PagedListResult<PodcastEpisode> {
        try await fetchWithCache(group: .podcasts, key: "podcasts:episodes:\(page):\(sort.drupalSort):\(tagTid ?? -1)") {
            var query: [String: String] = [
                "sort": sort.drupalSort,
                "include": "field_podcast,uid,taxonomy_vocabulary_15",
                "page[limit]": "\(Self.pageSize)",
                "page[offset]": "\(page * Self.pageSize)",
            ]
            if let tagTid { query["filter[taxonomy_vocabulary_15.drupal_internal__tid]"] = "\(tagTid)" }
            let response = try await client.jsonAPIList("node/podcast", query: query)
            let items = response.data.map { Mappers.podcast($0, included: response.included ?? []) }
            return PagedListResult(items: items, hasMore: response.hasNextPage)
        }
    }

    /// Live podcast tag vocabulary via the native REST endpoint (confirmed
    /// working: returns [{ tid, name, count }]).
    func tags() async throws -> [PodcastTag] {
        let raw: [JSONValue] = try await client.get("podcast/categories")
        return raw.compactMap { item -> PodcastTag? in
            guard let tid = item["tid"]?.stringValue.flatMap(Int.init) ?? item["tid"]?.intValue,
                  let name = item["name"]?.stringValue, tid > 0, !name.isEmpty else { return nil }
            return PodcastTag(id: "\(tid)", name: name, tid: tid, count: item["count"]?.intValue ?? 0)
        }
    }

    func episode(id: String) async throws -> PodcastEpisode {
        try await fetchWithCache(group: .podcasts, key: "podcasts:detail:\(id)") {
            let response = try await client.remapping400ToNotFound {
                try await client.jsonAPISingle(
                    "node/podcast/\(id)",
                    query: ["include": "field_podcast,uid,taxonomy_vocabulary_15"]
                )
            }
            return Mappers.podcast(response.data, included: response.included ?? [])
        }
    }

    /// Bundle confirmed: comment_node_podcast.
    func comments(episodeId: String) async throws -> [PodcastComment] {
        let response = try await client.jsonAPIList(
            "comment/comment_node_podcast",
            query: ["filter[entity_id.id]": episodeId, "sort": "created", "page[limit]": "100", "include": "uid"]
        )
        return response.data.map { node in
            let c = Mappers.genericComment(node, included: response.included ?? [])
            return PodcastComment(id: node.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
        }
    }

    func moreComments(episodeId: String, offset: Int) async throws -> [PodcastComment] {
        let response = try await client.jsonAPIList(
            "comment/comment_node_podcast",
            query: ["filter[entity_id.id]": episodeId, "sort": "created", "page[limit]": "100", "page[offset]": "\(offset)", "include": "uid"]
        )
        return response.data.map { node in
            let c = Mappers.genericComment(node, included: response.included ?? [])
            return PodcastComment(id: node.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
        }
    }

    @discardableResult
    func submitComment(episodeId: String, body: String, csrfToken: String) async throws -> PodcastComment {
        var attributes = CommentBundle.podcastEpisode.baseAttributes
        attributes["subject"] = AnyEncodable("Comment")
        attributes["comment_body"] = AnyEncodable(RichTextValue(value: body, format: drupalDefaultTextFormat))
        let response = try await client.jsonAPICreate(
            "comment/comment_node_podcast",
            type: "comment--comment_node_podcast",
            attributes: attributes,
            relationships: [
                "entity_id": JsonApiRelationshipRef(type: "node--podcast", id: episodeId),
                "comment_type": CommentBundle.podcastEpisode.commentTypeRelationship,
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
        let c = Mappers.genericComment(response.data, included: response.included ?? [])
        return PodcastComment(id: response.data.id, authorName: c.authorName, authorId: c.authorId, subject: c.subject, body: c.body, createdAt: c.createdAt)
    }

    func transcript(id: String) async throws -> String {
        struct Response: Decodable { let text: String? }
        let response: Response = try await client.get("podcasts/episodes/\(id)/transcript")
        return response.text ?? ""
    }
}

enum PodcastSort: String {
    case recent = "recent"
    case popular = "popular"

    /// Drupal has no true popularity metric — "popular" is approximated as
    /// most-recently-active (`-changed`), matching the RN reference client.
    var drupalSort: String {
        switch self {
        case .recent: return "-created"
        case .popular: return "-changed"
        }
    }
}
