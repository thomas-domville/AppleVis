import Foundation

extension APIClient {
    var history: HistoryEndpoints { HistoryEndpoints(client: self) }
}

/// Wraps Drupal core's built-in History module — the same mechanism the
/// AppleVis website itself uses to track what a signed-in user has read and
/// power its own "N new comments" indicators. Verified live against
/// applevis.com before building this: `POST /history/{nid}/read` returns a
/// real 200 with a Unix timestamp using nothing but the app's existing
/// session + CSRF auth. The bulk companion route Drupal core normally ships
/// (fetching read-timestamps for many nodes at once) came back a genuine
/// 404 on this install, not a Cloudflare block — so this only covers the
/// write side for now. There's no confirmed single "mark everything read"
/// route on this install either; marking several items read just means
/// calling this once per item, same as opening each one in the app already
/// does.
struct HistoryEndpoints {
    let client: APIClient

    /// Marks a node as read for the signed-in user, matching what the
    /// website already records when they view the same content in a
    /// browser. Fire-and-forget by design: this mirrors what the website
    /// already does silently in the background on page load, and a failure
    /// here (offline, expired session, node has no nid) shouldn't interrupt
    /// the content the user is actually trying to read.
    func markRead(nid: Int, csrfToken: String) async {
        guard nid > 0 else { return }
        struct EmptyBody: Encodable {}
        let _: Int? = try? await client.post(
            "history/\(nid)/read", base: .root, body: EmptyBody(), headers: ["X-CSRF-Token": csrfToken]
        )
    }
}
