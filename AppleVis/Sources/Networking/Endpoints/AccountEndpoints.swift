import Foundation

// MARK: - AccountEndpoints

struct AccountEndpoints {
    let client: APIClient

    private struct SignInResponse: Decodable {
        let currentUser: CurrentUser
        let csrfToken: String
        let logoutToken: String
        struct CurrentUser: Decodable { let uid: String; let name: String }

        enum CodingKeys: String, CodingKey {
            case currentUser = "current_user", csrfToken = "csrf_token", logoutToken = "logout_token"
        }
    }

    /// Signs in via Drupal's REST Simple Auth login endpoint, then resolves the
    /// account's JSON:API UUID and Drupal roles with follow-up requests — the
    /// login response itself does not include roles.
    func signIn(username: String, password: String) async throws -> AuthUser {
        struct Body: Encodable { let name: String; let pass: String }
        let body = Body(name: username, pass: password)
        let response: SignInResponse
        do {
            response = try await login(body: body)
        } catch APIError.forbidden {
            // Legacy Expo recovered from a real-world transient 403 by retrying
            // login once without cached credentials/cookies. Clear stale
            // AppleVis cookies before the retry, but still allow the successful
            // retry response to store Drupal's fresh authenticated session.
            // Otherwise sign-in can appear to work while follow-up JSON:API
            // writes fail as anonymous.
            clearAppleVisCookies()
            response = try await loginIgnoringCachedSession(body: body)
        }

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

    private func login(body: some Encodable) async throws -> SignInResponse {
        try await client.post(
            "user/login",
            base: .root,
            query: ["_format": "json"],
            body: body,
            headers: ["Accept": "application/json", "Content-Type": "application/json"]
        )
    }

    private func loginIgnoringCachedSession(body: some Encodable) async throws -> SignInResponse {
        try await client.post(
            "user/login",
            base: .root,
            query: ["_format": "json", "_": String(Int(Date().timeIntervalSince1970))],
            body: body,
            headers: [
                "Accept": "application/json",
                "Content-Type": "application/json",
                "Cache-Control": "no-cache",
                "Pragma": "no-cache"
            ],
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
    }

    private func clearAppleVisCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in cookies where cookie.domain.hasSuffix("applevis.com") {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    func logout(csrfToken: String, logoutToken: String) async throws {
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse? = try? await client.post(
            "user/logout",
            base: .root,
            query: ["_format": "json", "token": logoutToken],
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
        if let v = fields.facebook { attributes["field_profile_facebook"] = AnyEncodable(v) }
        if let v = fields.mastodon { attributes["field_profile_mastodon"] = AnyEncodable(v) }
        try await client.jsonAPIUpdate("user/user/\(uuid)", type: "user--user", id: uuid, attributes: attributes, headers: ["X-CSRF-Token": csrfToken])
    }

    /// Fetches the signed-in user's own editable profile fields — Edit
    /// Profile previously never loaded existing values at all, so every
    /// field always started blank even if the user already had a bio,
    /// location, etc. set, forcing a full retype for any small edit. Reads
    /// the exact same attribute keys `updateProfile` writes, so what you see
    /// here is guaranteed to round-trip correctly.
    func fetchProfileFields(uuid: String, csrfToken: String) async throws -> ProfileUpdateFields {
        let response = try await client.jsonAPISingle("user/user/\(uuid)", headers: ["X-CSRF-Token": csrfToken])
        let a = response.data.attributes
        func text(_ key: String) -> String {
            guard let value = a[key] else { return "" }
            if let s = value.stringValue { return s }
            return value["value"]?.stringValue ?? ""
        }
        return ProfileUpdateFields(
            realName: text("field_profile_realname"),
            bio: text("field_profile_bio"),
            location: text("field_profile_location"),
            interests: text("field_profile_interests"),
            homepage: text("field_profile_homepage"),
            twitter: text("field_profile_twitter"),
            facebook: text("field_profile_facebook"),
            mastodon: text("field_profile_mastodon")
        )
    }
}

struct ProfileUpdateFields {
    var realName: String?
    var bio: String?
    var location: String?
    var interests: String?
    var homepage: String?
    var twitter: String?
    var facebook: String?
    var mastodon: String?
}

private struct EmptyEncodable: Encodable {}

// MARK: - APIClient extension

extension APIClient {
    var account: AccountEndpoints { AccountEndpoints(client: self) }
}
