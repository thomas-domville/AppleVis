import Foundation

extension APIClient {
    var content: ContentActionEndpoints { ContentActionEndpoints(client: self) }
    var users: UserEndpoints { UserEndpoints(client: self) }
}

// MARK: - Content editing & deletion (comments, forum posts, generic nodes)

struct ContentActionEndpoints {
    let client: APIClient

    /// Fetches a comment's raw body + text format (needed before a PATCH, to
    /// preserve the existing format code).
    func fetchRawComment(commentType: String, commentId: String, csrfToken: String) async throws -> (rawValue: String, format: String) {
        let response = try await client.jsonAPISingle("comment/\(commentType)/\(commentId)", headers: ["X-CSRF-Token": csrfToken])
        let body = response.data.attributes["comment_body"]
        return (body?.richTextValue ?? "", body?["format"]?.stringValue ?? "basic_html")
    }

    func editComment(commentType: String, commentId: String, newBody: String, format: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "comment/\(commentType)/\(commentId)",
            type: "comment--\(commentType)", id: commentId,
            attributes: ["comment_body": AnyEncodable(RichTextValue(value: newBody, format: format))],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }

    func deleteComment(commentType: String, commentId: String, csrfToken: String) async throws {
        try await client.jsonAPIDelete("comment/\(commentType)/\(commentId)", headers: ["X-CSRF-Token": csrfToken])
    }

    func editForumPost(nodeId: String, title: String, body: String, csrfToken: String) async throws {
        try await editNode(nodeId: nodeId, nodeType: "forum", title: title, body: body, csrfToken: csrfToken)
    }

    func deleteForumPost(nodeId: String, csrfToken: String) async throws {
        try await deleteNode(nodeId: nodeId, nodeType: "forum", csrfToken: csrfToken)
    }

    /// Generic node DELETE — `nodeType` is the JSON:API type suffix
    /// ("forum", "podcast", "ios_app_directory", "guides", "blog2").
    func deleteNode(nodeId: String, nodeType: String, csrfToken: String) async throws {
        try await client.jsonAPIDelete("node/\(nodeType)/\(nodeId)", headers: ["X-CSRF-Token": csrfToken])
    }

    func unpublishNode(nodeId: String, nodeType: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "node/\(nodeType)/\(nodeId)", type: "node--\(nodeType)", id: nodeId,
            attributes: ["status": AnyEncodable(false)], headers: ["X-CSRF-Token": csrfToken]
        )
    }

    func editNode(nodeId: String, nodeType: String, title: String, body: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "node/\(nodeType)/\(nodeId)", type: "node--\(nodeType)", id: nodeId,
            attributes: [
                "title": AnyEncodable(title),
                "body": AnyEncodable(RichTextValue(value: body, format: "basic_html")),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }
}

// MARK: - Public user profiles & contact

struct UserEndpoints {
    let client: APIClient

    struct PublicProfile {
        let uuid: String
        let displayName: String
        let username: String
        let memberSince: Date
        let numericUid: Int
        let profileUrl: String?
        let location: String
        let bio: String
        let website: String
    }

    /// Fetches a public user profile by JSON:API UUID.
    func profile(uuid: String) async throws -> PublicProfile {
        let response = try await client.jsonAPISingle("user/user/\(uuid)")
        let a = response.data.attributes
        let alias = a["path"]?.pathAlias
        return PublicProfile(
            uuid: uuid,
            displayName: a["display_name"]?.stringValue ?? a["name"]?.stringValue ?? "",
            username: a["name"]?.stringValue ?? "",
            memberSince: response.data.createdDate,
            numericUid: a["drupal_internal__uid"]?.intValue ?? 0,
            profileUrl: alias.map { "https://www.applevis.com\($0)" },
            location: profileFieldText(a["field_location"]),
            bio: profileFieldText(a["field_bio"] ?? a["field_about"] ?? a["field_profile_bio"] ?? a["field_description"]),
            website: profileFieldText(a["field_website"] ?? a["field_url"] ?? a["field_homepage"])
        )
    }

    /// Sends a private contact message to another member via Drupal's Contact
    /// module. Requires an authenticated session (cookie-based).
    func sendContact(numericUid: Int, subject: String, message: String, csrfToken: String) async throws {
        struct Body: Encodable {
            let contactForm: [TargetRef]
            let subject: [ValueField]
            let message: [ValueField]
            let recipient: [NumericTargetRef]
            enum CodingKeys: String, CodingKey {
                case contactForm = "contact_form", subject, message, recipient
            }
            struct TargetRef: Encodable { let targetId: String; enum CodingKeys: String, CodingKey { case targetId = "target_id" } }
            struct NumericTargetRef: Encodable { let targetId: Int; enum CodingKeys: String, CodingKey { case targetId = "target_id" } }
            struct ValueField: Encodable { let value: String }
        }
        struct EmptyResponse: Decodable {}
        let body = Body(
            contactForm: [.init(targetId: "personal")],
            subject: [.init(value: subject)],
            message: [.init(value: message)],
            recipient: [.init(targetId: numericUid)]
        )
        let _: EmptyResponse? = try? await client.post(
            "contact_message", base: .root, query: ["_format": "json"], body: body, headers: ["X-CSRF-Token": csrfToken]
        )
    }

    private func profileFieldText(_ value: JSONValue?) -> String {
        if let s = value?.stringValue { return s }
        return value?["value"]?.stringValue ?? value?["processed"]?.stringValue ?? value?["uri"]?.stringValue ?? value?["title"]?.stringValue ?? ""
    }
}
