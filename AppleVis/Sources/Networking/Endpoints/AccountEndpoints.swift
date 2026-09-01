import Foundation
import os

// MARK: - AccountEndpoints

struct AccountEndpoints {
    let client: APIClient

    // No explicit CodingKeys here — APIClient's shared decoder already has
    // .convertFromSnakeCase, which converts "current_user" -> "currentUser"
    // before key matching. A manual `case currentUser = "current_user"`
    // then compares that already-converted key against its own un-converted
    // raw value and never matches, so decoding this response always threw
    // keyNotFound (100% sign-in failure, confirmed by live-testing against
    // the real API — the raw HTTP response was well-formed and correct).
    private struct SignInResponse: Decodable {
        let currentUser: CurrentUser
        let csrfToken: String
        let logoutToken: String
        struct CurrentUser: Decodable { let uid: String; let name: String }
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
        do {
            uuid = try await resolveUuid(csrfToken: response.csrfToken) ?? ""
            if !uuid.isEmpty {
                do {
                    roles = try await resolveRoles(uuid: uuid, csrfToken: response.csrfToken)
                } catch {
                    AppLog.auth.error("resolveRoles failed for uuid \(uuid, privacy: .private): \(error, privacy: .private)")
                }
            } else {
                AppLog.auth.error("resolveUuid returned no \"me\" link — roles cannot be resolved")
            }
        } catch {
            AppLog.auth.error("resolveUuid failed: \(error, privacy: .private)")
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

    /// Confirms `password` really is the signed-in user's *current* password
    /// by attempting a fresh login with it — the only reliable check
    /// available from the app's side, since a JSON:API PATCH to `user--user`
    /// has no built-in current-password requirement of its own (that
    /// enforcement lives only in the website's account edit form, which
    /// this app doesn't go through). Returns the fresh CSRF token from that
    /// login on success, valid for the change that follows; returns nil for
    /// a plain wrong-password rejection so the caller can show a specific
    /// "incorrect password" message instead of a generic one — any other
    /// failure (network, decoding) still throws.
    func verifyCurrentPassword(username: String, password: String) async throws -> String? {
        struct Body: Encodable { let name: String; let pass: String }
        do {
            let response = try await login(body: Body(name: username, pass: password))
            return response.csrfToken
        } catch APIError.forbidden, APIError.unauthorized {
            return nil
        }
    }

    /// Changes the signed-in user's password. Call only after
    /// `verifyCurrentPassword` has confirmed their current password, using
    /// the fresh CSRF token it returned.
    func changePassword(uuid: String, csrfToken: String, newPassword: String) async throws {
        try await client.jsonAPIUpdate(
            "user/user/\(uuid)", type: "user--user", id: uuid,
            attributes: ["pass": AnyEncodable(newPassword)],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }

    /// Changes the signed-in user's account email address. Call only after
    /// `verifyCurrentPassword` has confirmed their current password, using
    /// the fresh CSRF token it returned.
    func changeEmail(uuid: String, csrfToken: String, newEmail: String) async throws {
        try await client.jsonAPIUpdate(
            "user/user/\(uuid)", type: "user--user", id: uuid,
            attributes: ["mail": AnyEncodable(newEmail)],
            headers: ["X-CSRF-Token": csrfToken]
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
        // Confirmed against the live account edit form's HTML: this field's
        // real machine name is `field_mastodon_username`, not
        // `field_profile_mastodon` (every other social field follows the
        // `field_profile_*` convention, but this one doesn't) — Mastodon has
        // been silently failing to save/load ever since it was added.
        if let v = fields.mastodon { attributes["field_mastodon_username"] = AnyEncodable(v) }
        if let v = fields.owns { attributes["field_profile_owns"] = AnyEncodable(v) }
        // Core Drupal user fields, not `field_profile_*` custom fields —
        // confirmed against the live account edit form's "Locale settings"
        // (`timezone`) and "Contact settings" (`contact`) sections.
        if let v = fields.timezone { attributes["timezone"] = AnyEncodable(v) }
        if let v = fields.allowsContact { attributes["contact"] = AnyEncodable(v) }
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
            mastodon: text("field_mastodon_username"),
            owns: text("field_profile_owns"),
            timezone: text("timezone"),
            // Defaults to true (contactable) when missing, matching
            // Drupal's own default-enabled behavior for this checkbox.
            allowsContact: a["contact"]?.boolValue ?? true
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
    /// "Apple Products Owned" on the site (`field_profile_owns`) — a plain
    /// text field, even though the app presents it as checkboxes; see
    /// `DevicesPickerSheet` for the serialize/parse round-trip.
    var owns: String?
    /// Core Drupal field (`timezone`), an IANA identifier like
    /// "America/New_York" — not a `field_profile_*` custom field.
    var timezone: String?
    /// Core Drupal field (`contact`) — the site's "Personal contact form"
    /// checkbox. When false, other members should not see a Contact button
    /// on this person's public profile (site admins can still reach them
    /// through other means, per the site's own description of this
    /// setting).
    var allowsContact: Bool?
}

private struct EmptyEncodable: Encodable {}

// MARK: - APIClient extension

extension APIClient {
    var account: AccountEndpoints { AccountEndpoints(client: self) }
}
