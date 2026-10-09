import Foundation

nonisolated struct HistoryReadTarget: Hashable, Sendable, Codable {
    let uuid: String
    let nid: Int
    let bundles: [String]
}

/// A read the website hasn't heard about yet, with the moment it happened.
nonisolated struct PendingReadMark: Hashable, Sendable, Codable {
    let target: HistoryReadTarget
    let timestamp: Int

    var key: String { target.nid > 0 ? "nid:\(target.nid)" : target.uuid }
}

/// Reads made while offline (or when the website didn't answer), kept per
/// account and sent again later. Each one carries the time it was made:
/// the website keeps whichever read time is newer, so a late retry can
/// never hide replies posted after the member marked it. The website
/// forgets read records after 30 days and treats older items as read
/// anyway, so anything older is dropped rather than sent. Confirmed live
/// 2026-10-08.
enum PendingReadSync {
    static let maxAge: TimeInterval = 30 * 24 * 60 * 60
    static var isSending = false

    private static func key(_ userUuid: String) -> String { "pendingWebsiteReads.\(userUuid)" }

    static func load(for userUuid: String) -> [PendingReadMark] {
        guard let data = UserDefaults.standard.data(forKey: key(userUuid)),
              let marks = try? JSONDecoder().decode([PendingReadMark].self, from: data) else { return [] }
        let cutoff = Int(Date().timeIntervalSince1970 - maxAge)
        return marks.filter { $0.timestamp > cutoff }
    }

    /// Keeps one mark per item, the newest.
    static func add(_ marks: [PendingReadMark], for userUuid: String) {
        var byKey: [String: PendingReadMark] = [:]
        for mark in load(for: userUuid) + marks where (byKey[mark.key]?.timestamp ?? 0) < mark.timestamp {
            byKey[mark.key] = mark
        }
        save(Array(byKey.values), for: userUuid)
    }

    /// Removes marks that were sent or can't be sent, unless a newer read
    /// of the same item was added meanwhile.
    static func remove(_ marks: [PendingReadMark], for userUuid: String) {
        var done: [String: Int] = [:]
        for mark in marks { done[mark.key] = max(done[mark.key] ?? 0, mark.timestamp) }
        save(load(for: userUuid).filter { mark in done[mark.key].map { mark.timestamp > $0 } ?? true }, for: userUuid)
    }

    private static func save(_ marks: [PendingReadMark], for userUuid: String) {
        if marks.isEmpty { UserDefaults.standard.removeObject(forKey: key(userUuid)); return }
        if let data = try? JSONEncoder().encode(marks) { UserDefaults.standard.set(data, forKey: key(userUuid)) }
    }
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
    /// core History write per distinct item, stamped with the moment of the
    /// action. Anything that doesn't reach the website is kept and sent
    /// again later with that same time (see `PendingReadSync`).
    func syncMarkedRead(_ targets: [HistoryReadTarget]) {
        guard let user = AuthStore.current?.user, !targets.isEmpty else { return }
        let now = Int(Date().timeIntervalSince1970)
        let marks = Array(Set(targets)).map { PendingReadMark(target: $0, timestamp: now) }
        Task {
            let outcome = await send(marks, user: user)
            guard AuthStore.current?.user?.uuid == user.uuid, !outcome.retry.isEmpty else { return }
            PendingReadSync.add(outcome.retry, for: user.uuid)
            // On screen only: VoiceOver already heard it was marked, and
            // nothing needs doing; the website catches up by itself.
            APIClient.toastStore?.show(
                String(localized: "Marked as read. The website will catch up when you're back online."),
                kind: .warning, quiet: true
            )
        }
    }

    /// Sends reads saved earlier, quietly. Called when the app opens and
    /// when the connection comes back.
    func sendPendingReads() {
        Task { await sendPendingReadsNow() }
    }

    /// The same, finishing before it returns. Background refresh waits on
    /// this, since iOS may suspend the app as soon as it reports done.
    func sendPendingReadsNow() async {
        guard let user = AuthStore.current?.user, !PendingReadSync.isSending else { return }
        let pending = PendingReadSync.load(for: user.uuid)
        guard !pending.isEmpty else { return }
        PendingReadSync.isSending = true
        defer { PendingReadSync.isSending = false }
        let outcome = await send(pending, user: user)
        guard AuthStore.current?.user?.uuid == user.uuid else { return }
        PendingReadSync.remove(outcome.finished, for: user.uuid)
    }

    nonisolated private enum WriteResult: Sendable { case sent, retry, drop }

    /// `finished`: sent, or never sendable (item removed). `retry`: later.
    private func send(_ marks: [PendingReadMark], user: AuthUser) async -> (finished: [PendingReadMark], retry: [PendingReadMark]) {
        await withTaskGroup(of: (PendingReadMark, WriteResult).self) { group in
            var iterator = marks.makeIterator()
            for _ in 0..<4 {
                guard let mark = iterator.next() else { break }
                group.addTask { (mark, await write(mark, user: user)) }
            }
            var finished: [PendingReadMark] = []
            var retry: [PendingReadMark] = []
            while let (mark, result) = await group.next() {
                if result == .retry { retry.append(mark) } else { finished.append(mark) }
                if let next = iterator.next() {
                    group.addTask { (next, await write(next, user: user)) }
                }
            }
            return (finished, retry)
        }
    }

    private func write(_ mark: PendingReadMark, user: AuthUser) async -> WriteResult {
        let target = mark.target
        guard AuthStore.current?.user?.uuid == user.uuid, !Task.isCancelled else { return .retry }
        var nid = target.nid
        if nid <= 0 {
            if let cached = Self.resolvedNodeIds[target.uuid] { nid = cached }
            else {
                for bundle in target.bundles {
                    guard AuthStore.current?.user?.uuid == user.uuid, !Task.isCancelled else { return .retry }
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
                    catch { return .retry }
                }
                // Not found under any of its bundles: gone from the site.
                if nid <= 0 { return .drop }
            }
        }
        guard nid > 0, AuthStore.current?.user?.uuid == user.uuid, !Task.isCancelled else { return .retry }
        do {
            // The website keeps the newer of this and any read it already
            // has, and caps a time in the future at its own clock.
            struct ReadStamp: Encodable { let timestamp: Int }
            let stored: Int = try await client.post(
                "history/\(nid)/read", base: .root, body: ReadStamp(timestamp: mark.timestamp),
                headers: ["X-CSRF-Token": user.csrfToken]
            )
            return stored > 0 ? .sent : .retry
        } catch APIError.notFound { return .drop }
        catch APIError.forbidden { return .drop }
        catch APIError.refused { return .drop }
        catch { return .retry }
    }

    /// Marks a node as read for the signed-in user, matching what the
    /// website already records when they view the same content in a
    /// browser. Runs in the background on opening an item, and a failure
    /// (offline, website busy) never interrupts reading: the read is kept
    /// and sent again later with the time the item was opened.
    func markRead(nid: Int, csrfToken: String) async {
        guard nid > 0, let user = AuthStore.current?.user, user.csrfToken == csrfToken else { return }
        let mark = PendingReadMark(
            target: HistoryReadTarget(uuid: "", nid: nid, bundles: []),
            timestamp: Int(Date().timeIntervalSince1970)
        )
        if await write(mark, user: user) == .retry, AuthStore.current?.user?.uuid == user.uuid {
            PendingReadSync.add([mark], for: user.uuid)
        }
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
