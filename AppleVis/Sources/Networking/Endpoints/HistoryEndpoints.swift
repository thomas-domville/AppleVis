import Foundation

nonisolated struct HistoryReadTarget: Hashable, Sendable {
    let uuid: String
    let nid: Int
    let bundles: [String]
}

extension APIClient {
    var history: HistoryEndpoints { HistoryEndpoints(client: self) }
}

/// Wraps Drupal core's built-in History module — the same mechanism the
/// AppleVis website itself uses to track what a signed-in user has read and
/// power its own "N new comments" indicators. Verified live against
/// applevis.com before building this: `POST /history/{nid}/read` returns a
/// real 200 with a Unix timestamp using nothing but the app's existing
/// session + CSRF auth. The bulk companion route accepts form data rather
/// than JSON. There's no confirmed single "mark everything read"
/// route on this install either; marking several items read just means
/// calling this once per item, same as opening each one in the app already
/// does.
struct HistoryEndpoints {
    let client: APIClient

    static func target(id: String, nid: Int, kind: ContentKind) -> HistoryReadTarget {
        let bundles: [String]
        switch kind {
        case .appListing: bundles = ["ios_app_directory", "mac_app_directory", "tv_directory", "watch_directory"]
        case .bugReport: bundles = ["ios_bug_report", "os_x_bug_report"]
        default: bundles = [kind.nodeType.replacingOccurrences(of: "node--", with: "")]
        }
        return HistoryReadTarget(uuid: id, nid: nid, bundles: bundles)
    }

    /// Explicit full-read actions update locally immediately and send one
    /// core History write per distinct item. No delayed offline replay:
    /// this route stamps server time, which could hide later unread replies.
    func syncMarkedRead(_ targets: [HistoryReadTarget]) {
        guard let user = AuthStore.current?.user, !targets.isEmpty else { return }
        let unique = Array(Set(targets))
        Task {
            let success = await writeMarkedRead(unique, user: user)
            guard AuthStore.current?.user?.uuid == user.uuid, !success else { return }
            APIClient.toastStore?.error(String(localized: "Marked as read here. Couldn't update the website."))
        }
    }

    private func writeMarkedRead(_ targets: [HistoryReadTarget], user: AuthUser) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            var iterator = targets.makeIterator()
            for _ in 0..<4 {
                guard let target = iterator.next() else { break }
                group.addTask { await writeMarkedRead(target, user: user) }
            }
            var success = true
            while let result = await group.next() {
                success = success && result
                if let target = iterator.next() {
                    group.addTask { await writeMarkedRead(target, user: user) }
                }
            }
            return success
        }
    }

    private func writeMarkedRead(_ target: HistoryReadTarget, user: AuthUser) async -> Bool {
        guard AuthStore.current?.user?.uuid == user.uuid, !Task.isCancelled else { return false }
        var nid = target.nid
        if nid <= 0 {
            if let cached = Self.resolvedNodeIds[target.uuid] { nid = cached }
            else {
                for bundle in target.bundles {
                    guard AuthStore.current?.user?.uuid == user.uuid, !Task.isCancelled else { return false }
                    do {
                        let response = try await client.jsonAPISingle(
                            "node/\(bundle)/\(target.uuid)",
                            query: ["fields[node--\(bundle)]": "drupal_internal__nid"]
                        )
                        nid = response.data.attributes["drupal_internal__nid"]?.intValue ?? 0
                        if nid > 0 {
                            Self.resolvedNodeIds[target.uuid] = nid
                            break
                        }
                    } catch APIError.notFound { continue }
                    catch APIError.unknown(statusCode: 400) { continue }
                    catch { return false }
                }
            }
        }
        guard nid > 0, AuthStore.current?.user?.uuid == user.uuid, !Task.isCancelled else { return false }
        do {
            struct EmptyBody: Encodable {}
            let timestamp: Int = try await client.post(
                "history/\(nid)/read", base: .root, body: EmptyBody(),
                headers: ["X-CSRF-Token": user.csrfToken]
            )
            return timestamp > 0
        } catch { return false }
    }

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

    /// Signed-in Drupal history lookup. Indexed form keys encode node_ids[].
    /// Zero means no recorded read and never clears newer local history.
    func readStatus(nodeIds: [Int], csrfToken: String) async throws -> [Int: Date] {
        let ids = Array(Set(nodeIds.filter { $0 > 0 })).sorted()
        var result: [Int: Date] = [:]
        for start in stride(from: 0, to: ids.count, by: 100) {
            let batch = Array(ids[start..<min(start + 100, ids.count)])
            let body = Dictionary(uniqueKeysWithValues: batch.enumerated().map {
                ("node_ids[\($0.offset)]", String($0.element))
            })
            let response: [String: Int] = try await client.postForm(
                "history/get_node_read_timestamps", body: body,
                headers: ["X-CSRF-Token": csrfToken]
            )
            for (key, timestamp) in response {
                if let nid = Int(key), timestamp > 0 {
                    result[nid] = Date(timeIntervalSince1970: Double(timestamp))
                }
            }
        }
        return result
    }

    private static var resolvedNodeIds: [String: Int] = [:]

    /// Recent forum responses can omit nid. Resolve only the missing IDs;
    /// a failed item lookup must not prevent the rest of the batch syncing.
    func readDates(for items: [FeedItem], user: AuthUser) async throws -> [String: Date] {
        var nodeIds: [String: Int] = [:]
        var missing: [(key: String, uuid: String)] = []
        for item in items {
            if let nid = item.nid, nid > 0 { nodeIds[item.id] = nid }
            else if case .forumTopic = item {
                if let nid = Self.resolvedNodeIds[item.contentId] { nodeIds[item.id] = nid }
                else { missing.append((item.id, item.contentId)) }
            }
        }
        await withTaskGroup(of: (String, String, Int?).self) { group in
            var iterator = missing.makeIterator()
            for _ in 0..<4 {
                guard let item = iterator.next() else { break }
                group.addTask {
                    let response = try? await client.jsonAPISingle("node/forum/\(item.uuid)", query: ["fields[node--forum]": "drupal_internal__nid"])
                    return (item.key, item.uuid, response?.data.attributes["drupal_internal__nid"]?.intValue)
                }
            }
            while let (key, uuid, nid) = await group.next() {
                if let nid, nid > 0 {
                    Self.resolvedNodeIds[uuid] = nid
                    nodeIds[key] = nid
                }
                if let item = iterator.next() {
                    group.addTask {
                        let response = try? await client.jsonAPISingle("node/forum/\(item.uuid)", query: ["fields[node--forum]": "drupal_internal__nid"])
                        return (item.key, item.uuid, response?.data.attributes["drupal_internal__nid"]?.intValue)
                    }
                }
            }
        }
        guard AuthStore.current?.user?.uuid == user.uuid else { throw APIError.unauthorized }
        let dates = try await readStatus(nodeIds: Array(nodeIds.values), csrfToken: user.csrfToken)
        guard AuthStore.current?.user?.uuid == user.uuid else { throw APIError.unauthorized }
        return nodeIds.reduce(into: [:]) { result, pair in
            if let date = dates[pair.value] { result[pair.key] = date }
        }
    }
}
