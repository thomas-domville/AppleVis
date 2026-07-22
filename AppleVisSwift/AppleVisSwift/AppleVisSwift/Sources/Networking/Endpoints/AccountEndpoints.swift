import Foundation

// MARK: - AccountEndpoints

struct AccountEndpoints {
    let client: APIClient

    /// Signs in via Drupal's REST Simple Auth login endpoint, then resolves the
    /// account's JSON:API UUID and Drupal roles with follow-up requests — the
    /// login response itself does not include roles.
    func signIn(username: String, password: String) async throws -> AuthUser {
        struct Body: Encodable { let name: String; let pass: String }
        struct Response: Decodable {
            let currentUser: CurrentUser
            let csrfToken: String
            let logoutToken: String
            struct CurrentUser: Decodable { let uid: String; let name: String }

            enum CodingKeys: String, CodingKey {
                case currentUser = "current_user", csrfToken = "csrf_token", logoutToken = "logout_token"
            }
        }

        let response: Response = try await client.post(
            "user/login?_format=json",
            base: .root,
            body: Body(name: username, pass: password),
            headers: ["Accept": "application/json", "Content-Type": "application/json"]
        )

        var uuid = ""
        var roles: [String] = []
        if let resolvedUuid = try? await resolveUuid(csrfToken: response.csrfToken) {
            uuid = resolvedUuid
            roles = (try? await resolveRoles(uuid: resolvedUuid, csrfToken: response.csrfToken)) ?? []
        }

        return AuthUser(
            uid: response.currentUser.uid,
            uuid: uuid,
            name: response.currentUser.name,
            csrfToken: response.csrfToken,
            logoutToken: response.logoutToken,
            roles: roles
        )
    }

    func logout(csrfToken: String, logoutToken: String) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse? = try? await client.post(
            "user/logout?_format=json&token=\(logoutToken)",
            base: .root,
            body: EmptyEncodable(),
            headers: ["X-CSRF-Token": csrfToken]
        )
    }

    /// Resolves the signed-in user's JSON:API UUID via the collection endpoint's
    /// `meta.links.me` self-reference.
    func resolveUuid(csrfToken: String) async throws -> String? {
        let response = try await client.jsonAPIList("", headers: ["X-CSRF-Token": csrfToken])
        return response.links?["me"]?["meta"]?["id"]?.stringValue
    }

    /// Returns all Drupal role machine names assigned to this user. The
    /// relationship's `id` is always a role UUID; the machine name is exposed
    /// separately via `meta.drupal_internal__target_id`.
    func resolveRoles(uuid: String, csrfToken: String) async throws -> [String] {
        let response = try await client.jsonAPISingle("user/user/\(uuid)", headers: ["X-CSRF-Token": csrfToken])
        let roleRefs = response.data.relationships["roles"]?["data"]?.arrayValue ?? []
        return roleRefs.compactMap { $0["meta"]?["drupal_internal__target_id"]?.stringValue }
    }

    func deleteAccount(uuid: String, csrfToken: String) async throws {
        try await client.jsonAPIDelete("user/user/\(uuid)", headers: ["X-CSRF-Token": csrfToken])
    }

    func updateProfile(uuid: String, csrfToken: String, fields: ProfileUpdateFields) async throws {
        var attributes: [String: AnyEncodable] = [:]
        if let v = fields.realName { attributes["field_profile_realname"] = AnyEncodable(v) }
        if let v = fields.bio { attributes["field_profile_bio"] = AnyEncodable(v) }
        if let v = fields.location { attributes["field_profile_location"] = AnyEncodable(v) }
        if let v = fields.interests { attributes["field_profile_interests"] = AnyEncodable(v) }
        if let v = fields.homepage { attributes["field_profile_homepage"] = AnyEncodable(v) }
        if let v = fields.twitter { attributes["field_profile_twitter"] = AnyEncodable(v) }
        try await client.jsonAPIUpdate("user/user/\(uuid)", type: "user--user", id: uuid, attributes: attributes, headers: ["X-CSRF-Token": csrfToken])
    }
}

struct ProfileUpdateFields {
    var realName: String?
    var bio: String?
    var location: String?
    var interests: String?
    var homepage: String?
    var twitter: String?
}

private struct EmptyEncodable: Encodable {}

// MARK: - APIClient extension

extension APIClient {
    var account: AccountEndpoints { AccountEndpoints(client: self) }
}
