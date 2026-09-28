import Foundation

extension APIClient {
    var adminAccounts: AdminAccountEndpoints { AdminAccountEndpoints(client: self) }
}

/// A member account that was created a while ago and has never signed in.
nonisolated struct DormantAccount: Identifiable, Hashable, Sendable {
    /// JSON:API UUID — what the profile sheet and DELETE use.
    let id: String
    /// Drupal's numeric uid, for the website's /user/{uid} page.
    let uid: Int
    let username: String
    let displayName: String
    let createdAt: Date
    var isBlocked: Bool
    /// How many accounts share this one's sign-up burst, or 0 when it isn't
    /// part of one. Set by `DormantAccountStore.markBursts`.
    var burstSize: Int = 0

    var websiteURL: URL? {
        uid > 0 ? URL(string: "https://www.applevis.com/user/\(uid)") : nil
    }
}

/// Admin-only account tools, over plain JSON:API with the signed-in
/// admin's session. Confirmed live 2026-09-25 with a Site Admin account:
/// an admin session sees `created`, `access`, and `login` on `user--user`,
/// and the `access` filter runs server-side. An account that has never
/// signed in has `access` 0 (the API shows it as 1970). Signed-out and
/// non-admin sessions only ever see `display_name`, so this can't leak
/// anything to anyone else. No backend change was needed.
struct AdminAccountEndpoints {
    let client: APIClient

    /// Every account created at least `minimumAgeDays` ago that has never
    /// signed in, oldest first. Only the fields the list shows are
    /// requested (never email). About 420 accounts matched on 2026-09-25,
    /// nine pages; capped at 100 pages as a safety net.
    func dormantAccounts(minimumAgeDays: Int = 30, csrfToken: String, onProgress: (Int) -> Void = { _ in }) async throws -> [DormantAccount] {
        let cutoff = Int((Calendar.current.date(byAdding: .day, value: -minimumAgeDays, to: Date()) ?? Date()).timeIntervalSince1970)
        var results: [DormantAccount] = []
        var page = 0
        while page < 100 {
            let response = try await client.jsonAPIList(
                "user/user",
                query: [
                    "filter[access]": "0",
                    "filter[old][condition][path]": "created",
                    "filter[old][condition][operator]": "<=",
                    "filter[old][condition][value]": "\(cutoff)",
                    "sort": "created",
                    "fields[user--user]": "name,display_name,created,status,drupal_internal__uid",
                    "page[limit]": "50",
                    "page[offset]": "\(page * 50)",
                ],
                headers: ["X-CSRF-Token": csrfToken]
            )
            for node in response.data {
                let a = node.attributes
                results.append(DormantAccount(
                    id: node.id,
                    uid: a["drupal_internal__uid"]?.intValue ?? 0,
                    username: a["name"]?.stringValue ?? "",
                    displayName: a["display_name"]?.stringValue ?? a["name"]?.stringValue ?? "",
                    createdAt: node.createdDate,
                    isBlocked: a["status"]?.boolValue == false
                ))
            }
            onProgress(results.count)
            if !response.hasNextPage || response.data.isEmpty { break }
            page += 1
        }
        return results
    }

    /// Blocks or unblocks the account: Drupal's `status` field, the same
    /// "Blocked" the website's user list shows. Reversible, unlike delete.
    /// Confirmed live 2026-09-25: an admin session's PATCH of `status` is
    /// accepted (tested by re-blocking an already-blocked account, so
    /// nothing actually changed).
    func setBlocked(_ blocked: Bool, id: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "user/user/\(id)",
            type: "user--user",
            id: id,
            attributes: ["status": AnyEncodable(!blocked)],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }

    /// Permanently deletes the account. The accounts this screen lists
    /// have never signed in, so they have no posts or comments to lose.
    func deleteAccount(id: String, csrfToken: String) async throws {
        try await client.jsonAPIDelete("user/user/\(id)", headers: ["X-CSRF-Token": csrfToken])
    }
}
