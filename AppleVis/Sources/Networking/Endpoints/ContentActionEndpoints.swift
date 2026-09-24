import Foundation

extension APIClient {
    var content: ContentActionEndpoints { ContentActionEndpoints(client: self) }
    var users: UserEndpoints { UserEndpoints(client: self) }
}

// MARK: - Content editing & deletion (comments, forum posts, generic nodes)

struct ContentActionEndpoints {
    let client: APIClient

    /// `format` must be whatever the comment was actually stored in — see
    /// `editNode`'s identical doc comment for why.
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

    /// Mirrors `unpublishNode` — comments have their own `status` field,
    /// separate from the node they're attached to. Admin-only, distinct
    /// from delete: hides the comment from public view without removing it.
    func unpublishComment(commentType: String, commentId: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "comment/\(commentType)/\(commentId)", type: "comment--\(commentType)", id: commentId,
            attributes: ["status": AnyEncodable(false)], headers: ["X-CSRF-Token": csrfToken]
        )
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

    /// `format` must be whatever the content was actually stored in
    /// (e.g. `"7"` for Markdown) — not always `drupalDefaultTextFormat`.
    /// Resubmitting under a different format than the original can silently
    /// corrupt already-formatted content (e.g. Markdown source reinterpreted
    /// as Plain Text shows literal "### heading" instead of rendering it).
    func editNode(nodeId: String, nodeType: String, title: String, body: String, format: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "node/\(nodeType)/\(nodeId)", type: "node--\(nodeType)", id: nodeId,
            attributes: [
                "title": AnyEncodable(title),
                "body": AnyEncodable(RichTextValue(value: body, format: format)),
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
        let interests: String
        let twitter: String
        let mastodon: String
        let facebook: String
        /// "Apple Products Owned" on the site.
        let owns: String
        /// The site's "Personal contact form" setting — false means this
        /// person has opted out of being contacted by other members.
        let allowsContact: Bool
    }

    /// Fetches a public user profile by JSON:API UUID. Field names below are
    /// confirmed against the live account edit form's HTML (previously a
    /// few of these guessed at several possible names since nothing had
    /// verified them against the real site).
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
            location: profileFieldText(a["field_profile_location"]),
            bio: profileFieldText(a["field_profile_bio"]),
            website: profileFieldText(a["field_profile_homepage"]),
            interests: profileFieldText(a["field_profile_interests"]),
            twitter: profileFieldText(a["field_profile_twitter"]),
            mastodon: profileFieldText(a["field_mastodon_username"]),
            facebook: profileFieldText(a["field_profile_facebook"]),
            owns: profileFieldText(a["field_profile_owns"]),
            // Defaults to true (contactable) if this field isn't readable
            // anonymously — the safe direction is showing the button and
            // letting Drupal's own access check reject the send, not
            // hiding a real contact option because a field came back empty.
            allowsContact: a["contact"]?.boolValue ?? true
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
        let _: EmptyResponse = try await client.post(
            "contact_message", base: .root, query: ["_format": "json"], body: body, headers: ["X-CSRF-Token": csrfToken]
        )
    }

    private func profileFieldText(_ value: JSONValue?) -> String {
        if let s = value?.stringValue { return s }
        return value?["value"]?.stringValue ?? value?["processed"]?.stringValue ?? value?["uri"]?.stringValue ?? value?["title"]?.stringValue ?? ""
    }
}
