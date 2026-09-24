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

    /// Speculative — matches the shape proposed to the Drupal contractor
    /// 2026-09-22 for a bulk "read status for many nodes at once" endpoint.
    /// The core companion route Drupal normally ships for this
    /// (`history/get_node_read_timestamps`) 404s on this install (see
    /// `markRead`'s doc comment), so there's nothing confirmed to build
    /// against yet — this is our proposed contract, not his. Not wired into
    /// any UI: exists as a ready-to-use building block so the only change
    /// needed once he replies is this function's path/response shape, not a
    /// new call site. Update to match whatever he actually implements.
    func readStatus(nodeIds: [Int], csrfToken: String) async throws -> [Int: Date] {
        struct RequestBody: Encodable {
            let nodeIds: [Int]
            enum CodingKeys: String, CodingKey { case nodeIds = "node_ids" }
        }
        let response: [String: Int] = try await client.post(
            "history-status", base: .v1, body: RequestBody(nodeIds: nodeIds), headers: ["X-CSRF-Token": csrfToken]
        )
        return response.reduce(into: [:]) { result, pair in
            guard let nid = Int(pair.key), pair.value > 0 else { return }
            result[nid] = Date(timeIntervalSince1970: Double(pair.value))
        }
    }
}
